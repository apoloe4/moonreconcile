///|
// Injective over all UInt64 inputs; the finite input domain here excludes zero.
// Use the same integer formula in the independent minisketch driver.
fn identifier(index : Int, seed : Int) -> UInt64 {
  (index.to_uint64() + 1UL + seed.to_uint64() * 1000003UL) *
  6364136223846793005UL
}

///|
fn scenario(n : Int, d : Int, ratio : Int, seed : Int) -> Unit raise {
  let width = if d == 0 { 1 } else { d * ratio / 2 }
  let config = @reconcile.Config::new(width, seed=seed.to_uint64())
  let build_start = @bench.monotonic_clock_start()
  let a = @reconcile.Sketch::new(config)
  let b = @reconcile.Sketch::new(config)
  for i = 0; i < n; i = i + 1 {
    a.insert(identifier(i, seed))
    b.insert(identifier(i + d / 2, seed))
  }
  let build_us = @bench.monotonic_clock_end(build_start)
  let decode_start = @bench.monotonic_clock_start()
  let report = b.subtract(a).decode(budget=d + 1)
  let decode_us = @bench.monotonic_clock_end(decode_start)
  if report.complete() {
    let negative = Array::makei(d / 2, fn(i) { identifier(i, seed) })
    let positive = Array::makei(d / 2, fn(i) { identifier(n + i, seed) })
    positive.sort()
    negative.sort()
    assert_eq(report.positive(), positive)
    assert_eq(report.negative(), negative)
  }
  println(
    "\{n},\{d},\{ratio},\{seed},\{width},\{report.complete()},\{report.residual_cells()},\{report.steps()},\{config.wire_bytes()},\{n.to_int64() * 8L},\{build_us},\{decode_us}",
  )
}

///|
fn run() -> Unit raise {
  if @env.args().contains("--sessions") {
    session_matrix()
    return
  }
  let full = @env.args().contains("--full")
  let sizes = if full { [1000, 10000, 100000] } else { [1000, 10000] }
  let differences = if full { [0, 2, 20, 200, 2000] } else { [0, 2, 20, 200] }
  let seeds = if full { 100 } else { 10 }
  println(
    "members,differences,ratio_twice,seed,width,complete,residual,steps,frame_bytes,full_id_bytes,build_us,decode_us",
  )
  for n in sizes {
    for d in differences {
      for ratio in [1, 2, 4] {
        for seed = 1; seed <= seeds; seed = seed + 1 {
          scenario(n, d, ratio, seed)
        }
      }
    }
  }
  // Extra one-way and high-difference cases are verified by the session and
  // core property tests; this CSV isolates the declared balanced matrix.
}

///|
fn session_matrix() -> Unit raise {
  println(
    "members,differences,seed,budget,complete,reason,rounds,sent_bytes,received_bytes,steps,full_id_bytes",
  )
  for n in [1000, 10000] {
    for d in [0, 2, 20, 200] {
      for seed = 1; seed <= 10; seed = seed + 1 {
        let a = @reconcile.Inventory::from_ids(
          Array::makei(n, fn(i) { identifier(i, seed) }),
        )
        let b = @reconcile.Inventory::from_ids(
          Array::makei(n, fn(i) { identifier(i + d / 2, seed) }),
        )
        for budget in [512L, 65536L] {
          let initial = @reconcile.Config::new(1, seed=seed.to_uint64())
          let session = @reconcile.Session::new(
            a.snapshot(initial),
            b.epoch(),
            @reconcile.SessionLimits::new(max_bytes=budget, max_rounds=16),
          )
          for config = initial {
            let source = a.snapshot(config)
            match session.record_sent(source.encode()) {
              Stopped(_) => break
              _ => ()
            }
            match session.receive(source, b.snapshot(config).encode()) {
              Awaiting(next) => continue next
              _ => break
            }
          }
          let (complete, reason) = match session.state() {
            Complete(plan) => {
              assert_eq(a.apply(plan).ids(), b.ids())
              (true, "complete")
            }
            Stopped(reason) => (false, reason.label())
            _ => fail("session loop must terminate")
          }
          println(
            "\{n},\{d},\{seed},\{budget},\{complete},\{reason},\{session.rounds()},\{session.sent_bytes()},\{session.received_bytes()},\{session.decode_steps()},\{n.to_int64() * 8L}",
          )
        }
      }
    }
  }
}

///|
fn main {
  run() catch {
    e => abort(e.to_string())
  }
}
