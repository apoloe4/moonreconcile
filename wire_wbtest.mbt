///|
fn damage(data : Bytes, index : Int, value : Byte) -> Bytes {
  let bytes = data.to_array()
  bytes[index] = value
  Bytes::from_array(bytes)
}

///|
fn resign(data : Bytes) -> Bytes {
  let out = data.to_array()
  let crc = crc32(data, data.length() - 4)
  for i = 0; i < 4; i = i + 1 {
    out[data.length() - 4 + i] = (crc >> (8 * i)).to_byte()
  }
  Bytes::from_array(out)
}

///|
test "snapshot roundtrip is canonical for empty and occupied inventories" {
  for count in [0, 1, 50, 1000] {
    let ids = Array::makei(count, fn(i) { i.to_uint64() })
    let snapshot = Inventory::from_ids(ids, scope=91UL, epoch=24UL).snapshot(
      Config::new(50, seed=999UL),
    )
    let data = snapshot.encode()
    assert_eq(data.length(), snapshot.encoded_size())
    let decoded = Snapshot::decode(data, DecodeLimits::new())
    assert_eq(decoded.encode(), data)
    assert_eq(decoded.fingerprint(), snapshot.fingerprint())
    assert_eq(decoded.epoch(), 24UL)
  }
}

///|
test "all truncation positions rejected without panic" {
  let data = Inventory::from_ids([0UL, 1UL, 99UL])
    .snapshot(Config::new(3))
    .encode()
  for size = 0; size < data.length(); size = size + 1 {
    let truncated = Bytes::from_array(data.to_array()[:size])
    expect_error(() => {
      Snapshot::decode(truncated, DecodeLimits::new()) |> ignore
    })
  }
}

///|
test "every flipped byte rejects corruption" {
  let data = Inventory::from_ids([3UL, 4UL]).snapshot(Config::new(10)).encode()
  for i = 0; i < data.length(); i = i + 1 {
    expect_error(() => {
      Snapshot::decode(damage(data, i, data[i] ^ 1), DecodeLimits::new())
      |> ignore
    })
  }
}

///|
test "width and members are bounded before allocation" {
  let data = Inventory::from_ids([1UL, 2UL]).snapshot(Config::new(8)).encode()
  expect_error(() => {
    Snapshot::decode(data, DecodeLimits::new(max_width=7)) |> ignore
  })
  expect_error(() => {
    Snapshot::decode(data, DecodeLimits::new(max_members=1)) |> ignore
  })
  expect_error(() => {
    Snapshot::decode(
      resign(damage(data, 8, 255)),
      DecodeLimits::new(max_width=100),
    )
    |> ignore
  })
}

///|
test "semantic corruption rejected even with corrected CRC" {
  let data = Inventory::new().snapshot(Config::new(2)).encode()
  expect_error(() => {
    Snapshot::decode(resign(damage(data, 68, 1)), DecodeLimits::new()) |> ignore
  })
  expect_error(() => {
    Snapshot::decode(resign(damage(data, 40, 1)), DecodeLimits::new()) |> ignore
  })
  expect_error(() => {
    Snapshot::decode(resign(damage(data, 56, 1)), DecodeLimits::new()) |> ignore
  })
}

///|
test "all chunk sizes decode one identical snapshot" {
  let data = Inventory::from_ids([0UL, 30UL, 70UL])
    .snapshot(Config::new(6))
    .encode()
  for chunk_size in [1, 2, 3, 16, 64, 128, 1000] {
    let reader = FrameReader::new(DecodeLimits::new())
    let mut offset = 0
    let mut completed = false
    while offset < data.length() {
      let end = if offset + chunk_size < data.length() {
        offset + chunk_size
      } else {
        data.length()
      }
      let chunk = Bytes::from_array(data.to_array()[offset:end])
      if reader.feed(chunk) is Some(snapshot) {
        assert_eq(snapshot.encode(), data)
        completed = true
      }
      offset = end
    }
    assert_true(completed)
    reader.finish()
    expect_error(() => reader.feed(b"") |> ignore)
  }
}

///|
test "stream rejects trailing bytes truncated EOF and can reset" {
  let reader = FrameReader::new(DecodeLimits::new(max_width=5))
  reader.feed(b"MRCL") |> ignore
  expect_error(() => reader.finish())
  expect_error(() => reader.feed(b"") |> ignore)
  reader.reset()
  let valid = Inventory::new().snapshot(Config::new(2)).encode()
  let extra = valid.to_array()
  extra.push(0)
  expect_error(() => reader.feed(Bytes::from_array(extra)) |> ignore)
  assert_eq(reader.buffered_bytes(), 0)
  reader.reset()
  assert_true(reader.feed(valid) is Some(_))
}

///|
test "stream rejects malicious declared width at first 16 bytes" {
  let reader = FrameReader::new(DecodeLimits::new(max_width=5))
  let header = b"MRCL\x01\x00\x00\x00\xff\xff\xff\x7f\x00\x00\x00\x00"
  expect_error(() => reader.feed(header) |> ignore)
  assert_eq(reader.buffered_bytes(), 0)
}

///|
test "manifest canonical roundtrip and corruption" {
  let manifest = Inventory::from_ids([1UL, 3UL, 6UL], scope=1UL, epoch=2UL).manifest(
    Layout::new(8),
  )
  let bytes = manifest.encode()
  assert_eq(Manifest::decode(bytes).encode(), bytes)
  expect_error(() => Manifest::decode(bytes, max_buckets=7) |> ignore)
  expect_error(() => Manifest::decode(bytes, max_members=2) |> ignore)
  for i = 0; i < bytes.length(); i = i + 1 {
    expect_error(() => {
      Manifest::decode(damage(bytes, i, bytes[i] ^ 1)) |> ignore
    })
  }
  expect_error(() => {
    Manifest::decode(resign(damage(bytes, 40, bytes[40] ^ 1))) |> ignore
  })
}

///|
test "random bytes never panic the snapshot or manifest decoder" {
  for size = 0; size < 500; size = size + 1 {
    let data = Bytes::from_array(
      Array::makei(size, fn(i) { mix((size * 1000 + i).to_uint64()).to_byte() }),
    )
    expect_error(() => {
      Snapshot::decode(data, DecodeLimits::new(max_width=20)) |> ignore
    })
    expect_error(() => Manifest::decode(data, max_buckets=20) |> ignore)
  }
}
