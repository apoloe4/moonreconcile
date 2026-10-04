///|
test "partition recovery requests only changed buckets" {
  let a = Inventory::from_ids(
    Array::makei(1000, fn(i) { i.to_uint64() }),
    scope=4UL,
    epoch=20UL,
  )
  let b = Inventory::from_ids(a.ids(), scope=4UL, epoch=30UL)
  b.remove(1UL) |> ignore
  b.insert(1001UL) |> ignore
  let layout = Layout::new(32)
  let ma = Manifest::decode(a.manifest(layout).encode())
  let mb = Manifest::decode(b.manifest(layout).encode())
  let dirty = ma.changed_buckets(mb)
  assert_true(dirty.length() <= 2)
  let collector = Collector::new(ma, mb)
  expect_error(() => collector.finish() |> ignore)
  let config = Config::new(8)
  let offers_a = a.bucket_offers(layout, dirty, config)
  let offers_b = b.bucket_offers(layout, dirty, config)
  for i = 0; i < dirty.length(); i = i + 1 {
    let wire_b = BucketOffer::new(
      dirty[i],
      layout,
      Snapshot::decode(offers_b[i].snapshot().encode(), DecodeLimits::new()),
    )
    ready(collector.accept(offers_a[i], wire_b, Policy::new())) |> ignore
    // Retransmitted successful bucket is idempotent.
    ready(collector.accept(offers_a[i], wire_b, Policy::new())) |> ignore
  }
  assert_eq(collector.pending(), [])
  let plan = collector.finish()
  assert_eq(plan.additions(), [1001UL])
  assert_eq(plan.removals(), [1UL])
  assert_eq(a.apply(plan).ids(), b.ids())
}

///|
test "identical manifests need no bucket offers" {
  let a = Inventory::from_ids([1UL, 4UL, 5UL], epoch=1UL)
  let b = Inventory::from_ids(a.ids(), epoch=9UL)
  let layout = Layout::new(16)
  let collector = Collector::new(a.manifest(layout), b.manifest(layout))
  assert_eq(collector.pending(), [])
  assert_eq(a.apply(collector.finish()).epoch(), 9UL)
}

///|
test "bucket allocation and invalid request limits" {
  let a = Inventory::new()
  let layout = Layout::new(8)
  expect_error(() => Layout::new(4097) |> ignore)
  expect_error(() => a.bucket_offers(layout, [1, 1], Config::new(4)) |> ignore)
  expect_error(() => a.bucket_offers(layout, [8], Config::new(4)) |> ignore)
  expect_error(() => {
    a.bucket_offers(layout, [1, 2], Config::new(4), max_cells=23) |> ignore
  })
  expect_error(() => a.bucket_offer(layout, -1, Config::new(4)) |> ignore)
}

///|
test "bucket stale snapshot cannot mutate collector" {
  let a = Inventory::from_ids([1UL])
  let b = Inventory::from_ids([2UL])
  let layout = Layout::new(1)
  let collector = Collector::new(a.manifest(layout), b.manifest(layout))
  b.insert(3UL) |> ignore
  expect_error(() => {
    collector.accept(
      a.bucket_offer(layout, 0, Config::new(10)),
      b.bucket_offer(layout, 0, Config::new(10)),
      Policy::new(),
    )
    |> ignore
  })
  assert_eq(collector.pending(), [0])
}

///|
test "bucket incomplete decoding never produces global plan" {
  let a = Inventory::from_ids([1UL, 2UL, 3UL])
  let b = Inventory::from_ids([4UL, 5UL, 6UL])
  let layout = Layout::new(1)
  let collector = Collector::new(a.manifest(layout), b.manifest(layout))
  match
    collector.accept(
      a.bucket_offer(layout, 0, Config::new(1)),
      b.bucket_offer(layout, 0, Config::new(1)),
      Policy::new(),
    ) {
    Retry(_) => ()
    _ => fail("expected retry")
  }
  expect_error(() => collector.finish() |> ignore)
  ready(
    collector.accept(
      a.bucket_offer(layout, 0, Config::new(32)),
      b.bucket_offer(layout, 0, Config::new(32)),
      Policy::new(),
    ),
  )
  |> ignore
  assert_eq(a.apply(collector.finish()).ids(), b.ids())
}

///|
test "single bucket and batched offers agree" {
  let a = Inventory::from_ids(Array::makei(500, fn(i) { i.to_uint64() }))
  let layout = Layout::new(11)
  let config = Config::new(5)
  let batch = a.bucket_offers(layout, [2, 0, 8], config)
  for i, index in [2, 0, 8] {
    assert_eq(
      batch[i].snapshot().encode(),
      a.bucket_offer(layout, index, config).snapshot().encode(),
    )
  }
}
