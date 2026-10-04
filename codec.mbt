///|
/// Per-call limits are checked before allocating the cell array.
pub struct DecodeLimits {
  max_width : Int
  max_members : Int
}

///|
pub fn DecodeLimits::new(
  max_width? : Int = 65536,
  max_members? : Int = 10000000,
) -> DecodeLimits raise ReconcileError {
  if max_width < 1 || max_width > 262144 || max_members < 0 {
    raise InvalidConfig("invalid wire decode limits")
  }
  { max_width, max_members, }
}

///|
fn put_u32(out : Array[Byte], value : UInt) -> Unit {
  for i = 0; i < 4; i = i + 1 {
    out.push((value >> (i * 8)).to_byte())
  }
}

///|
fn put_u64(out : Array[Byte], value : UInt64) -> Unit {
  for i = 0; i < 8; i = i + 1 {
    out.push((value >> (i * 8)).to_byte())
  }
}

///|
fn get_u32(data : Bytes, offset : Int) -> UInt {
  let mut value = 0U
  for i = 0; i < 4; i = i + 1 {
    value = value | (data[offset + i].to_uint() << (8 * i))
  }
  value
}

///|
fn get_u64(data : Bytes, offset : Int) -> UInt64 {
  let mut value = 0UL
  for i = 0; i < 8; i = i + 1 {
    value = value | (data[offset + i].to_uint64() << (8 * i))
  }
  value
}

///|
// IEEE CRC-32 detects accidental damage only, not a malicious peer.
fn crc32(data : Bytes, end : Int) -> UInt {
  let mut crc = 0xffffffffU
  for i = 0; i < end; i = i + 1 {
    crc = crc ^ data[i].to_uint()
    for j = 0; j < 8; j = j + 1 {
      crc = if (crc & 1U) != 0U { (crc >> 1) ^ 0xedb88320U } else { crc >> 1 }
    }
  }
  crc ^ 0xffffffffU
}

///|
/// MRCL v1, little-endian, fixed 64-byte header and 20-byte cells.
pub fn Snapshot::encode(self : Snapshot) -> Bytes {
  let out : Array[Byte] = [77, 82, 67, 76, 1, 0, 0, 0]
  put_u32(out, self.sketch.config.width.reinterpret_as_uint())
  put_u32(out, self.fingerprint.count.reinterpret_as_uint())
  put_u64(out, self.sketch.config.seed)
  put_u64(out, self.scope)
  put_u64(out, self.epoch)
  put_u64(out, self.fingerprint.sum)
  put_u64(out, self.fingerprint.xor)
  put_u64(out, 0UL)
  for cell in self.sketch.cells {
    put_u32(out, cell.count.reinterpret_as_uint())
    put_u64(out, cell.key)
    put_u64(out, cell.check)
  }
  let payload = Bytes::from_array(out)
  put_u32(out, crc32(payload, payload.length()))
  Bytes::from_array(out)
}

///|
pub fn Snapshot::encoded_size(self : Snapshot) -> Int {
  68 + self.sketch.config.cells() * 20
}

///|
/// Wire accepts inventory snapshots, not arbitrary signed difference tables.
/// Strict length/version/reserved-byte checks precede CRC and allocation.
pub fn Snapshot::decode(
  data : Bytes,
  limits : DecodeLimits,
) -> Snapshot raise ReconcileError {
  if data.length() < 68 {
    raise InvalidFrame("truncated header")
  }
  if data[0] != 77 || data[1] != 82 || data[2] != 67 || data[3] != 76 {
    raise InvalidFrame("bad magic")
  }
  if data[4] != 1 ||
    data[5] != 0 ||
    data[6] != 0 ||
    data[7] != 0 ||
    get_u64(data, 56) != 0UL {
    raise InvalidFrame("unsupported version or reserved fields")
  }
  let width_raw = get_u32(data, 8)
  let count_raw = get_u32(data, 12)
  if width_raw == 0U || width_raw > limits.max_width.reinterpret_as_uint() {
    raise LimitExceeded("frame width")
  }
  if count_raw > limits.max_members.reinterpret_as_uint() {
    raise LimitExceeded("frame members")
  }
  let width = width_raw.reinterpret_as_int()
  let members = count_raw.reinterpret_as_int()
  let expected = 68 + width * 60
  if data.length() != expected {
    raise InvalidFrame("incorrect frame length")
  }
  if get_u32(data, expected - 4) != crc32(data, expected - 4) {
    raise InvalidFrame("CRC mismatch")
  }
  let config = Config::new(width, seed=get_u64(data, 16))
  let sketch = Sketch::new(config)
  let counts : Array[Int64] = [0L, 0L, 0L]
  let band_keys : Array[UInt64] = [0UL, 0UL, 0UL]
  let band_checks : Array[UInt64] = [0UL, 0UL, 0UL]
  for i = 0; i < config.cells(); i = i + 1 {
    let offset = 64 + 20 * i
    let raw = get_u32(data, offset)
    if raw > count_raw {
      raise InvalidFrame("cell count exceeds inventory size")
    }
    let count = raw.reinterpret_as_int()
    let key = get_u64(data, offset + 4)
    let check = get_u64(data, offset + 12)
    if count == 0 && (key != 0UL || check != 0UL) {
      raise InvalidFrame("nonempty zero-count inventory cell")
    }
    if count == 1 &&
      (
        check != check_key(key, config.seed) ||
        !positions(key, config).contains(i)
      ) {
      raise InvalidFrame("invalid singleton")
    }
    sketch.cells[i] = { count, key, check, }
    let band = i / width
    counts[band] = counts[band] + count.to_int64()
    band_keys[band] = band_keys[band] ^ key
    band_checks[band] = band_checks[band] ^ check
  }
  for band = 0; band < 3; band = band + 1 {
    if counts[band] != members.to_int64() ||
      band_keys[band] != band_keys[0] ||
      band_checks[band] != band_checks[0] {
      raise InvalidFrame("inconsistent hash bands")
    }
  }
  let fingerprint : Fingerprint = {
    count: members,
    sum: get_u64(data, 40),
    xor: get_u64(data, 48),
  }
  if members == 0 && fingerprint != empty_fingerprint() {
    raise InvalidFrame("invalid empty fingerprint")
  }
  { scope: get_u64(data, 24), epoch: get_u64(data, 32), fingerprint, sketch, }
}
