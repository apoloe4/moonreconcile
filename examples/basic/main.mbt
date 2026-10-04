///|
fn run() -> Unit raise {
  let source = @reconcile.Inventory::from_ids(
    [1UL, 2UL, 3UL, 4UL],
    scope=42UL,
    epoch=7UL,
  )
  let target = @reconcile.Inventory::from_ids(
    [2UL, 3UL, 5UL],
    scope=42UL,
    epoch=9UL,
  )
  let config = @reconcile.Config::new(16)
  let received = @reconcile.Snapshot::decode(
    target.snapshot(config).encode(),
    @reconcile.DecodeLimits::new(),
  )
  match
    @reconcile.reconcile(
      source.snapshot(config),
      received,
      @reconcile.Policy::new(),
    ) {
    Ready(plan) => {
      println("新增 ID: \{@debug.to_string(plan.additions())}")
      println("移除 ID: \{@debug.to_string(plan.removals())}")
      let result = source.apply(plan)
      println("同步结果: \{@debug.to_string(result.ids())}")
      println("目标版本: \{result.epoch()}")
      assert_eq(result.ids(), target.ids())
    }
    Retry(next) => println("需要重试，分带宽度: \{next.width()}")
    FullTransfer(residual) =>
      println("需要全量同步，残留单元: \{residual}")
  }
}

///|
fn main {
  run() catch {
    error => abort(error.to_string())
  }
}
