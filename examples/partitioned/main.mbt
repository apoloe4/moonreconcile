///|
fn run() -> Unit raise {
  let source = @reconcile.Inventory::from_ids(
    Array::makei(10000, fn(i) { i.to_uint64() }),
    scope=9UL,
  )
  let target = @reconcile.Inventory::from_ids(source.ids(), scope=9UL)
  target.remove(123UL) |> ignore
  target.insert(20000UL) |> ignore
  let layout = @reconcile.Layout::new(64)
  let source_manifest = source.manifest(layout)
  let remote_manifest = @reconcile.Manifest::decode(
    target.manifest(layout).encode(),
  )
  let collector = @reconcile.Collector::new(source_manifest, remote_manifest)
  let pending = collector.pending()
  println("总分区: \{layout.buckets()}，发生变化: \{pending.length()}")
  let initial = @reconcile.Config::new(4)
  let policy = @reconcile.Policy::new(max_width=4096)
  let mut sketch_bytes = 0
  for index in pending {
    for config = initial {
      let source_offer = source.bucket_offer(layout, index, config)
      let remote_bytes = target
        .bucket_offer(layout, index, config)
        .snapshot()
        .encode()
      sketch_bytes += remote_bytes.length()
      let received = @reconcile.BucketOffer::new(
        index,
        layout,
        @reconcile.Snapshot::decode(
          remote_bytes,
          @reconcile.DecodeLimits::new(),
        ),
      )
      match collector.accept(source_offer, received, policy) {
        Ready(_) => break
        Retry(next) => continue next
        FullTransfer(_) => abort("此示例数据不应需要全量同步")
      }
    }
  }
  let plan = collector.finish()
  let result = source.apply(plan)
  assert_eq(result.ids(), target.ids())
  println(
    "新增: \{@debug.to_string(plan.additions())}，移除: \{@debug.to_string(plan.removals())}",
  )
  println("接收清单字节: \{remote_manifest.encode().length()}")
  println("接收摘要字节（含重试）: \{sketch_bytes}")
  println(
    "远端全量 ID 数组字节（不含封装）: \{target.ids().length() * 8}",
  )
}

///|
fn main {
  run() catch {
    error => abort(error.to_string())
  }
}
