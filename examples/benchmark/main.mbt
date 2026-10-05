///|
fn measure(
  source_ids : Array[UInt64],
  target_ids : Array[UInt64],
  config : @reconcile.Config,
) -> (Double, Double, Double, Double) raise {
  let start = @bench.monotonic_clock_start()
  let source = @reconcile.Snapshot::from_sorted_ids(source_ids.iter(), config)
  let target = @reconcile.Snapshot::from_sorted_ids(target_ids.iter(), config)
  let build_us = @bench.monotonic_clock_end(start)
  let wire_start = @bench.monotonic_clock_start()
  let received = @reconcile.Snapshot::decode(
    target.encode(),
    @reconcile.DecodeLimits::new(),
  )
  let wire_us = @bench.monotonic_clock_end(wire_start)
  let decode_start = @bench.monotonic_clock_start()
  let outcome = @reconcile.reconcile(source, received, @reconcile.Policy::new())
  let reconcile_us = @bench.monotonic_clock_end(decode_start)
  match outcome {
    Ready(plan) => {
      let inventory = @reconcile.Inventory::from_ids(source_ids)
      let apply_start = @bench.monotonic_clock_start()
      let result = inventory.apply(plan)
      let apply_us = @bench.monotonic_clock_end(apply_start)
      assert_eq(result.ids(), target_ids)
      (build_us, wire_us, reconcile_us, apply_us)
    }
    _ => fail("benchmark failed to recover; no timing row is emitted")
  }
}

///|
fn run() -> Unit raise {
  println(
    "members,changed_each_side,seed,width,received_bytes,build_two_us,encode_decode_us,reconcile_us,apply_us",
  )
  for members in [1000, 10000] {
    for changed in [0, 10, 100] {
      for seed in [1UL, 17UL] {
        let capacity = @reconcile.CapacityPlan::new(changed * 2, seed~)
        let config = capacity.initial()
        let source = Array::makei(members, fn(i) { i.to_uint64() })
        let target = Array::makei(members, fn(i) { (i + changed).to_uint64() })
        // Discard one warmup; report means of five verified repetitions.
        measure(source, target, config) |> ignore
        let mut build = 0.0
        let mut wire = 0.0
        let mut recover = 0.0
        let mut apply = 0.0
        for round = 0; round < 5; round = round + 1 {
          let (a, b, c, d) = measure(source, target, config)
          build += a
          wire += b
          recover += c
          apply += d
        }
        println(
          "\{members},\{changed},\{seed},\{config.width()},\{config.wire_bytes()},\{build / 5.0},\{wire / 5.0},\{recover / 5.0},\{apply / 5.0}",
        )
      }
    }
  }
}

///|
fn main {
  run() catch {
    error => abort(error.to_string())
  }
}
