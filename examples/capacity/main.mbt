///|
fn run() -> Unit raise {
  let source = @reconcile.Inventory::new()
  let target = @reconcile.Inventory::from_ids(
    Array::makei(200, fn(i) { i.to_uint64() }),
  )
  let config = @reconcile.Config::new(1)
  let limited = @reconcile.Policy::new(max_width=1)
  match
    @reconcile.reconcile(
      source.snapshot(config),
      target.snapshot(config),
      limited,
    ) {
    FullTransfer(residual) =>
      println(
        "容量不足，明确返回全量同步建议，残留: \{residual}",
      )
    _ => abort("预期返回容量不足")
  }
  match
    @reconcile.synchronize(
      source,
      target,
      config,
      @reconcile.Policy::new(max_width=1024),
    ) {
    Ready(plan) => {
      assert_eq(source.apply(plan).ids(), target.ids())
      println("扩大摘要后成功恢复 \{plan.additions().length()} 个 ID")
    }
    _ => abort("预期重试后成功")
  }
}

///|
fn main {
  run() catch {
    error => abort(error.to_string())
  }
}
