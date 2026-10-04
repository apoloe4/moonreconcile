///|
fn expect_error(f : () -> Unit raise ReconcileError) -> Unit raise {
  try f() catch {
    ReconcileError::InvalidConfig(_)
    | ReconcileError::Incompatible(_)
    | ReconcileError::InvalidFrame(_)
    | ReconcileError::LimitExceeded(_)
    | ReconcileError::StaleSnapshot
    | ReconcileError::VerificationFailed
    | ReconcileError::InvalidPlan(_) => ()
  } noraise {
    _ => fail("expected ReconcileError")
  }
}

///|
fn ready(outcome : Outcome) -> Plan raise {
  match outcome {
    Ready(plan) => plan
    _ => fail("expected complete reconciliation")
  }
}

///|
test "configuration rejects resource hazards" {
  expect_error(() => Config::new(0) |> ignore)
  expect_error(() => Config::new(262145) |> ignore)
  expect_error(() => Policy::new(max_differences=-1) |> ignore)
  expect_error(() => DecodeLimits::new(max_width=0) |> ignore)
  assert_eq(Config::new(32).cells(), 96)
}

///|
test "splitmix finalizer published constants" {
  assert_eq(mix(0UL), 0UL)
  assert_eq(mix(1UL), 0x5692161d100b05e5UL)
  assert_eq(crc32(b"123456789", 9), 0xcbf43926U)
}

///|
test "three positions always distinct and in band" {
  for width in [1, 2, 7, 100] {
    let config = Config::new(width)
    for id = 0; id < 1000; id = id + 1 {
      let p = positions(id.to_uint64(), config)
      for band = 0; band < 3; band = band + 1 {
        assert_true(p[band] >= band * width && p[band] < (band + 1) * width)
      }
    }
  }
}

///|
test "zero and maximum ID are representable" {
  let sketch = Sketch::new(Config::new(32))
  sketch.insert(0UL)
  sketch.insert(0xffffffffffffffffUL)
  let report = sketch.decode()
  assert_true(report.complete())
  assert_eq(report.positive(), [0UL, 0xffffffffffffffffUL])
}

///|
test "balanced insert erase produces zero table" {
  let sketch = Sketch::new(Config::new(1))
  for id = 0; id < 200; id = id + 1 {
    sketch.insert(id.to_uint64())
  }
  for id = 0; id < 200; id = id + 1 {
    sketch.erase(id.to_uint64())
  }
  assert_true(sketch.decode().complete())
}

///|
test "decode preserves table and returned arrays are defensive" {
  let sketch = Sketch::new(Config::new(64))
  sketch.insert(5UL)
  sketch.erase(6UL)
  let first = sketch.decode()
  first.positive().push(99UL)
  assert_eq(first.positive(), [5UL])
  assert_eq(first.negative(), [6UL])
  assert_eq(sketch.decode().positive(), [5UL])
}

///|
test "counter update overflow is atomic" {
  let sketch = Sketch::new(Config::new(5))
  let p = positions(42UL, sketch.config)
  sketch.cells[p[2]].count = 2147483647
  expect_error(() => sketch.insert(42UL))
  assert_eq(sketch.cells[p[0]].count, 0)
  assert_eq(sketch.cells[p[1]].key, 0UL)
}

///|
test "subtraction overflow and mismatch rejected" {
  let a = Sketch::new(Config::new(1))
  let b = a.copy()
  a.cells[0].count = 2147483647
  b.cells[0].count = -1
  expect_error(() => a.subtract(b) |> ignore)
  expect_error(() => a.subtract(Sketch::new(Config::new(2))) |> ignore)
}

///|
test "insufficient capacity never claims a complete empty result" {
  let a = Inventory::from_ids([1UL, 2UL, 3UL, 4UL])
  let report = a.snapshot(Config::new(1)).sketch.decode()
  assert_false(report.complete())
  assert_eq(report.residual_cells(), 3)
}

///|
test "budget stops decode explicitly" {
  let a = Inventory::from_ids([10UL, 11UL, 12UL])
  let report = a.snapshot(Config::new(100)).sketch.decode(budget=1)
  assert_eq(report.steps(), 1)
  assert_false(report.complete())
  expect_error(() => {
    a.snapshot(Config::new(1)).sketch.decode(budget=-1) |> ignore
  })
}

///|
test "invalid duplicate multiplicity cannot decode as set" {
  let sketch = Sketch::new(Config::new(20))
  sketch.insert(8UL)
  sketch.insert(8UL)
  assert_false(sketch.decode().complete())
}

///|
test "Inventory de-duplicates and idempotent changes preserve epoch" {
  let inventory = Inventory::from_ids([2UL, 2UL, 3UL], epoch=4UL)
  assert_eq(inventory.ids(), [2UL, 3UL])
  assert_false(inventory.insert(2UL))
  assert_false(inventory.remove(9UL))
  assert_eq(inventory.epoch(), 4UL)
  assert_true(inventory.insert(9UL))
  assert_true(inventory.remove(2UL))
  assert_eq(inventory.epoch(), 6UL)
  assert_eq(
    inventory.fingerprint(),
    Inventory::from_ids([3UL, 9UL]).fingerprint(),
  )
}

///|
test "epoch overflow leaves inventory intact" {
  let inventory = Inventory::from_ids([1UL], epoch=0xffffffffffffffffUL)
  expect_error(() => inventory.insert(2UL) |> ignore)
  expect_error(() => inventory.remove(1UL) |> ignore)
  assert_eq(inventory.ids(), [1UL])
}

///|
test "directional synchronization after wire roundtrip" {
  let a = Inventory::from_ids([1UL, 2UL, 3UL], scope=8UL, epoch=10UL)
  let b = Inventory::from_ids([2UL, 3UL, 4UL], scope=8UL, epoch=7UL)
  let config = Config::new(30)
  let remote = Snapshot::decode(
    b.snapshot(config).encode(),
    DecodeLimits::new(),
  )
  let plan = ready(reconcile(a.snapshot(config), remote, Policy::new()))
  assert_eq(plan.additions(), [4UL])
  assert_eq(plan.removals(), [1UL])
  let synced = a.apply(plan)
  assert_eq(synced.ids(), b.ids())
  assert_eq(synced.epoch(), 7UL)
  assert_eq(a.ids(), [1UL, 2UL, 3UL])
}

///|
test "scope mismatch and stale plan rejected" {
  let a = Inventory::from_ids([1UL], scope=7UL)
  let b = Inventory::from_ids([2UL], scope=7UL)
  let config = Config::new(20)
  let plan = ready(
    reconcile(a.snapshot(config), b.snapshot(config), Policy::new()),
  )
  expect_error(() => {
    reconcile(
      a.snapshot(config),
      Inventory::new(scope=8UL).snapshot(config),
      Policy::new(),
    )
    |> ignore
  })
  a.insert(9UL) |> ignore
  expect_error(() => a.apply(plan) |> ignore)
  assert_eq(a.ids(), [1UL, 9UL])
}

///|
test "fingerprint tampering rejected even when peel completes" {
  let a = Inventory::new()
  let b = Inventory::from_ids([1UL]).snapshot(Config::new(8))
  let forged : Snapshot = { ..b, fingerprint: empty_fingerprint(), }
  expect_error(() => {
    reconcile(a.snapshot(Config::new(8)), forged, Policy::new()) |> ignore
  })
}

///|
test "retry doubles width until ready and respects cap" {
  let a = Inventory::from_ids([1UL, 2UL, 3UL, 4UL, 5UL])
  let b = Inventory::from_ids([6UL, 7UL, 8UL, 9UL, 10UL])
  match
    reconcile(
      a.snapshot(Config::new(1)),
      b.snapshot(Config::new(1)),
      Policy::new(),
    ) {
    Retry(config) => assert_eq(config.width(), 2)
    _ => fail("must retry")
  }
  let plan = ready(
    synchronize(a, b, Config::new(1), Policy::new(max_width=128)),
  )
  assert_eq(a.apply(plan).ids(), b.ids())
  match synchronize(a, b, Config::new(1), Policy::new(max_width=1)) {
    FullTransfer(_) => ()
    _ => fail("must fall back")
  }
}

///|
test "hundreds of generated overlapping sets equal exact differences" {
  for seed = 1; seed <= 100; seed = seed + 1 {
    let a = Inventory::new()
    let b = Inventory::new()
    for id = 0; id < 100; id = id + 1 {
      let key = mix((id + seed * 1000).to_uint64())
      if id % 3 != 0 {
        a.insert(key) |> ignore
      }
      if id % 4 != 0 {
        b.insert(key) |> ignore
      }
    }
    let plan = ready(
      synchronize(
        a,
        b,
        Config::new(4, seed=seed.to_uint64()),
        Policy::new(max_width=512),
      ),
    )
    assert_eq(plan.additions(), b.ids().filter(fn(id) { !a.contains(id) }))
    assert_eq(plan.removals(), a.ids().filter(fn(id) { !b.contains(id) }))
    assert_eq(a.apply(plan).ids(), b.ids())
  }
}
