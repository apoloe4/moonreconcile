///|
/// MRPM v1: 64-byte header, 24 bytes per partition fingerprint, CRC-32.
pub fn Manifest::encode(self : Manifest) -> Bytes {
  let out : Array[Byte] = [77, 82, 80, 77, 1, 0, 0, 0]
  put_u32(out, self.layout.buckets.reinterpret_as_uint())
  put_u32(out, self.total.count.reinterpret_as_uint())
  put_u64(out, self.layout.seed)
  put_u64(out, self.scope)
  put_u64(out, self.epoch)
  put_u64(out, self.total.sum)
  put_u64(out, self.total.xor)
  put_u64(out, 0UL)
  for fp in self.fingerprints {
    put_u32(out, fp.count.reinterpret_as_uint())
    put_u32(out, 0U)
    put_u64(out, fp.sum)
    put_u64(out, fp.xor)
  }
  let payload = Bytes::from_array(out)
  put_u32(out, crc32(payload, payload.length()))
  Bytes::from_array(out)
}

///|
pub fn Manifest::decode(
  data : Bytes,
  max_buckets? : Int = 4096,
  max_members? : Int = 10000000,
) -> Manifest raise ReconcileError {
  if max_buckets < 1 || max_buckets > 4096 || max_members < 0 {
    raise InvalidConfig("invalid manifest limits")
  }
  if data.length() < 68 {
    raise InvalidFrame("truncated manifest")
  }
  if data[0] != 77 ||
    data[1] != 82 ||
    data[2] != 80 ||
    data[3] != 77 ||
    data[4] != 1 ||
    data[5] != 0 ||
    data[6] != 0 ||
    data[7] != 0 ||
    get_u64(data, 56) != 0UL {
    raise InvalidFrame("manifest magic, version or reserved fields")
  }
  let buckets_raw = get_u32(data, 8)
  let count_raw = get_u32(data, 12)
  if buckets_raw == 0U ||
    buckets_raw > max_buckets.reinterpret_as_uint() ||
    count_raw > max_members.reinterpret_as_uint() {
    raise LimitExceeded("manifest allocation or member limit")
  }
  let buckets = buckets_raw.reinterpret_as_int()
  if data.length() != 68 + 24 * buckets {
    raise InvalidFrame("manifest length")
  }
  if get_u32(data, data.length() - 4) != crc32(data, data.length() - 4) {
    raise InvalidFrame("manifest CRC")
  }
  let fingerprints : Array[Fingerprint] = []
  let mut count = 0L
  let mut sum = 0UL
  let mut xor = 0UL
  for i = 0; i < buckets; i = i + 1 {
    let offset = 64 + i * 24
    let raw = get_u32(data, offset)
    if raw > count_raw || get_u32(data, offset + 4) != 0U {
      raise InvalidFrame("manifest partition count or flags")
    }
    let fp : Fingerprint = {
      count: raw.reinterpret_as_int(),
      sum: get_u64(data, offset + 8),
      xor: get_u64(data, offset + 16),
    }
    if fp.count == 0 && fp != empty_fingerprint() {
      raise InvalidFrame("nonempty zero-count manifest partition")
    }
    count += fp.count.to_int64()
    sum += fp.sum
    xor = xor ^ fp.xor
    fingerprints.push(fp)
  }
  let total : Fingerprint = {
    count: count_raw.reinterpret_as_int(),
    sum: get_u64(data, 40),
    xor: get_u64(data, 48),
  }
  if count != total.count.to_int64() || sum != total.sum || xor != total.xor {
    raise InvalidFrame("manifest totals mismatch")
  }
  {
    scope: get_u64(data, 24),
    epoch: get_u64(data, 32),
    total,
    fingerprints,
    layout: Layout::new(buckets, seed=get_u64(data, 16)),
  }
}
