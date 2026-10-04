///|
test "large common set cancels despite tiny sketch" {
  let common = Array::makei(10000, fn(i) { i.to_uint64() })
  let a = Inventory::from_ids(common)
  let b = Inventory::from_ids(common)
  b.insert(99999UL) |> ignore
  let config = Config::new(1)
  let plan = ready(
    reconcile(a.snapshot(config), b.snapshot(config), Policy::new()),
  )
  assert_eq(plan.additions(), [99999UL])
  assert_eq(plan.removals(), [])
  assert_eq(a.apply(plan).ids(), b.ids())
}

///|
test "difference inverse and common additions preserve result" {
  for seed = 0; seed < 30; seed = seed + 1 {
    let config = Config::new(100, seed=seed.to_uint64())
    let a = Inventory::from_ids([0UL, 7UL, 11UL, 90UL])
    let b = Inventory::from_ids([7UL, 8UL, 90UL, 100UL])
    let ab = b.snapshot(config).sketch
      .subtract(a.snapshot(config).sketch)
      .decode()
    let ba = a.snapshot(config).sketch
      .subtract(b.snapshot(config).sketch)
      .decode()
    assert_true(ab.complete() && ba.complete())
    assert_eq(ab.positive(), ba.negative())
    assert_eq(ab.negative(), ba.positive())
    for id = 1000; id < 2000; id = id + 1 {
      a.insert(id.to_uint64()) |> ignore
      b.insert(id.to_uint64()) |> ignore
    }
    let enlarged = b.snapshot(config).sketch
      .subtract(a.snapshot(config).sketch)
      .decode()
    assert_eq(enlarged.positive(), ab.positive())
    assert_eq(enlarged.negative(), ab.negative())
  }
}

///|
test "aggregate collector limit rejects atomically" {
  let a = Inventory::from_ids([1UL, 2UL])
  let b = Inventory::from_ids([3UL, 4UL])
  let layout = Layout::new(1)
  let collector = Collector::new(
    a.manifest(layout),
    b.manifest(layout),
    max_changes=3,
  )
  expect_error(() => {
    collector.accept(
      a.bucket_offer(layout, 0, Config::new(30)),
      b.bucket_offer(layout, 0, Config::new(30)),
      Policy::new(),
    )
    |> ignore
  })
  assert_eq(collector.pending(), [0])
  assert_eq(collector.accepted_changes, 0)
}

///|
test "apply verifies invalid additions removals and target fingerprint" {
  let source = Inventory::from_ids([1UL], scope=3UL, epoch=1UL)
  let target = Inventory::from_ids([2UL], scope=3UL, epoch=2UL)
  let good = ready(synchronize(source, target, Config::new(20), Policy::new()))
  let missing : Plan = { ..good, remove: [99UL], }
  let duplicate : Plan = { ..good, remove: [], add: [1UL], }
  let tampered : Plan = { ..good, target: empty_fingerprint(), }
  expect_error(() => source.apply(missing) |> ignore)
  expect_error(() => source.apply(duplicate) |> ignore)
  expect_error(() => source.apply(tampered) |> ignore)
  assert_eq(source.ids(), [1UL])
}

///|
test "wire minimum frame golden layout" {
  let data = Inventory::new().snapshot(Config::new(1, seed=0UL)).encode()
  assert_eq(data.length(), 128)
  assert_eq(get_u32(data, 0), 0x4c43524dU)
  assert_eq(get_u32(data, 8), 1U)
  for i = 12; i < 124; i = i + 1 {
    assert_eq(data[i], 0)
  }
  assert_eq(get_u32(data, 124), crc32(data, 124))
}
