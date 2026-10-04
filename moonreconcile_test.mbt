///|
test "public API supports encoded snapshot synchronization" {
  let source = @moonreconcile.Inventory::from_ids([1UL, 2UL, 3UL])
  let target = @moonreconcile.Inventory::from_ids([2UL, 4UL], epoch=99UL)
  let config = @moonreconcile.Config::new(32)
  let decoded = @moonreconcile.Snapshot::decode(
    target.snapshot(config).encode(),
    @moonreconcile.DecodeLimits::new(),
  )
  match
    @moonreconcile.reconcile(
      source.snapshot(config),
      decoded,
      @moonreconcile.Policy::new(),
    ) {
    Ready(plan) => {
      plan.additions().push(100UL)
      plan.removals().clear()
      assert_eq(source.apply(plan).ids(), target.ids())
      assert_eq(plan.target_epoch(), 99UL)
    }
    _ => fail("expected complete plan")
  }
}

///|
test "public snapshot stays frozen when inventory changes" {
  let inventory = @moonreconcile.Inventory::from_ids([1UL, 2UL])
  let snapshot = inventory.snapshot(@moonreconcile.Config::new(16))
  let before = snapshot.encode()
  inventory.insert(3UL) |> ignore
  inventory.ids().clear()
  assert_eq(snapshot.encode(), before)
  assert_eq(snapshot.fingerprint().count(), 2)
  assert_eq(inventory.fingerprint().count(), 3)
}

///|
test "public partition offers and collector preserve isolation" {
  let source = @moonreconcile.Inventory::from_ids([1UL, 2UL])
  let target = @moonreconcile.Inventory::from_ids([1UL, 3UL])
  let layout = @moonreconcile.Layout::new(1)
  let config = @moonreconcile.Config::new(32)
  let collector = @moonreconcile.Collector::new(
    source.manifest(layout),
    target.manifest(layout),
  )
  collector.pending().clear()
  assert_eq(collector.pending(), [0])
  collector.accept(
    source.bucket_offer(layout, 0, config),
    target.bucket_offer(layout, 0, config),
    @moonreconcile.Policy::new(),
  )
  |> ignore
  assert_eq(source.apply(collector.finish()).ids(), target.ids())
}
