///|
test "sorted cursor matches exact Inventory snapshot bytes" {
  for count in [0, 1, 100, 10000] {
    let ids = Array::makei(count, fn(i) { i.to_uint64() * 7UL })
    let config = Config::new(37, seed=17UL)
    let streamed = Snapshot::from_sorted_ids(
      ids.iter(),
      config,
      scope=42UL,
      epoch=88UL,
    )
    let exact = Inventory::from_ids(ids, scope=42UL, epoch=88UL).snapshot(
      config,
    )
    assert_eq(streamed.encode(), exact.encode())
  }
}

///|
test "sorted cursor accepts full UInt64 range and rejects duplicates" {
  let config = Config::new(32)
  let data = Snapshot::from_sorted_ids(
    [0UL, 0xffffffffffffffffUL].iter(),
    config,
  )
  assert_eq(data.sketch.decode().positive(), [0UL, 0xffffffffffffffffUL])
  expect_error(() => {
    Snapshot::from_sorted_ids([1UL, 1UL].iter(), config) |> ignore
  })
  expect_error(() => {
    Snapshot::from_sorted_ids([2UL, 1UL].iter(), config) |> ignore
  })
}

///|
test "sorted cursor enforces member limits including empty input" {
  let config = Config::new(1)
  assert_eq(
    Snapshot::from_sorted_ids([].iter(), config, max_members=0)
    .fingerprint()
    .count(),
    0,
  )
  assert_eq(
    Snapshot::from_sorted_ids([1UL].iter(), config, max_members=1)
    .fingerprint()
    .count(),
    1,
  )
  expect_error(() => {
    Snapshot::from_sorted_ids([1UL, 2UL].iter(), config, max_members=1)
    |> ignore
  })
  expect_error(() => {
    Snapshot::from_sorted_ids([].iter(), config, max_members=-1) |> ignore
  })
}
