///|
fn stopped(state : SessionState, reason : SessionStop) -> Unit raise {
  match state {
    Stopped(actual) => assert_eq(actual, reason)
    _ => fail("expected stopped session")
  }
}

///|
fn next_config(state : SessionState) -> Config raise {
  match state {
    Awaiting(config) => config
    _ => fail("expected another sketch")
  }
}

///|
test "session exchanges encoded frames and applies an exact plan" {
  let a = Inventory::from_ids([0UL, 1UL, 2UL], scope=7UL, epoch=10UL)
  let b = Inventory::from_ids([0UL, 2UL, 3UL], scope=7UL, epoch=20UL)
  let config = Config::new(16)
  let source = a.snapshot(config)
  let session = Session::new(source, b.epoch(), SessionLimits::new())
  session.record_sent(source.encode()) |> ignore
  match session.receive(source, b.snapshot(config).encode()) {
    Complete(plan) => assert_eq(a.apply(plan).ids(), b.ids())
    _ => fail("small difference should recover")
  }
  assert_eq(session.rounds(), 1)
  assert_eq(session.sent_bytes(), 1028L)
  assert_eq(session.received_bytes(), 1028L)
  assert_eq(session.decode_steps(), 2)
}

///|
test "session counts retransmissions without spending rounds or decode steps" {
  let a = Inventory::from_ids([1UL, 2UL, 3UL])
  let b = Inventory::from_ids([4UL, 5UL, 6UL])
  let initial = Config::new(1)
  let source = a.snapshot(initial)
  let session = Session::new(source, b.epoch(), SessionLimits::new())
  let first = b.snapshot(initial).encode()
  session.record_sent(source.encode()) |> ignore
  session.record_sent(source.encode()) |> ignore
  let next = next_config(session.receive(source, first))
  assert_eq(next.width(), 2)
  assert_eq(next_config(session.receive(source, first)), next)
  assert_eq(session.rounds(), 1)
  assert_eq(session.decode_steps(), 0)
  assert_eq(session.sent_bytes(), 256L)
  assert_eq(session.received_bytes(), 256L)
  let mut config = next
  for _attempt = 0; _attempt < 7; _attempt = _attempt + 1 {
    let current_source = a.snapshot(config)
    session.record_sent(current_source.encode()) |> ignore
    match session.receive(current_source, b.snapshot(config).encode()) {
      Awaiting(next) => config = next
      Complete(plan) => {
        assert_eq(a.apply(plan).ids(), b.ids())
        break
      }
      Stopped(_) => fail("unexpected stop")
    }
  }
  match session.state() {
    Complete(_) => ()
    _ => fail("retry loop did not finish")
  }
}

///|
test "session accepts exact byte budget and stops one byte short" {
  let source = Inventory::new().snapshot(Config::new(1))
  let wire = source.encode()
  let exact = Session::new(source, 0UL, SessionLimits::new(max_bytes=256L))
  exact.record_sent(wire) |> ignore
  match exact.receive(source, wire) {
    Complete(_) => ()
    _ => fail("exact budget must succeed")
  }
  let short = Session::new(source, 0UL, SessionLimits::new(max_bytes=255L))
  short.record_sent(wire) |> ignore
  stopped(short.receive(source, wire), ByteLimit)
  assert_eq(short.received_bytes(), 128L)
  let before_send = Session::new(
    source,
    0UL,
    SessionLimits::new(max_bytes=127L),
  )
  stopped(before_send.record_sent(wire), ByteLimit)
  assert_eq(before_send.sent_bytes(), 0L)
}

///|
test "session stops at round and width limits instead of returning partial plans" {
  let a = Inventory::from_ids([1UL, 2UL, 3UL]).snapshot(Config::new(1))
  let b = Inventory::from_ids([4UL, 5UL, 6UL]).snapshot(Config::new(1))
  let round_limit = Session::new(a, 0UL, SessionLimits::new(max_rounds=1))
  stopped(round_limit.receive(a, b.encode()), RoundLimit)
  assert_eq(round_limit.rounds(), 1)
  let width_limit = Session::new(a, 0UL, SessionLimits::new(max_width=1))
  stopped(width_limit.receive(a, b.encode()), WidthLimit)
}

///|
test "session cumulative decode work is bounded and exact completion is allowed" {
  let config = Config::new(16)
  let a = Inventory::from_ids([1UL]).snapshot(config)
  let b = Inventory::from_ids([2UL]).snapshot(config)
  let limited = Session::new(a, 0UL, SessionLimits::new(max_steps=1))
  stopped(limited.receive(a, b.encode()), WorkLimit)
  assert_eq(limited.decode_steps(), 1)
  let exact = Session::new(a, 0UL, SessionLimits::new(max_steps=2))
  match exact.receive(a, b.encode()) {
    Complete(_) => assert_eq(exact.decode_steps(), 2)
    _ => fail("exact work budget should complete")
  }
  let empty_work = Session::new(a, 0UL, SessionLimits::new(max_steps=0))
  match empty_work.receive(a, a.encode()) {
    Complete(_) => assert_eq(empty_work.decode_steps(), 0)
    _ => fail("identical sets need no peeling")
  }
}

///|
test "session detects changed source even when an old frame is replayed" {
  let config = Config::new(1)
  let a = Inventory::from_ids([1UL, 2UL, 3UL])
  let source = a.snapshot(config)
  let frame = Inventory::from_ids([4UL, 5UL, 6UL]).snapshot(config).encode()
  let session = Session::new(source, 0UL, SessionLimits::new())
  session.receive(source, frame) |> ignore
  a.insert(9UL) |> ignore
  stopped(session.receive(a.snapshot(config), frame), SnapshotChanged)
}

///|
test "session pins target fingerprint even if a writer reuses its epoch" {
  let config = Config::new(1)
  let a = Inventory::from_ids([1UL, 2UL, 3UL])
  let source = a.snapshot(config)
  let session = Session::new(source, 0UL, SessionLimits::new())
  let first = Inventory::from_ids([4UL, 5UL, 6UL]).snapshot(config)
  let next = next_config(session.receive(source, first.encode()))
  let changed = Inventory::from_ids([4UL, 5UL, 9UL]).snapshot(next)
  stopped(session.receive(a.snapshot(next), changed.encode()), SnapshotChanged)
}

///|
test "session rejects wrong target scope epoch seed and malformed frames" {
  let config = Config::new(1)
  let a = Inventory::new().snapshot(config)
  for
    remote in [
      Inventory::new(scope=1UL).snapshot(config),
      Inventory::new(epoch=1UL).snapshot(config),
    ] {
    let session = Session::new(a, 0UL, SessionLimits::new())
    stopped(session.receive(a, remote.encode()), SnapshotChanged)
  }
  let wrong_seed = Inventory::new().snapshot(Config::new(1, seed=2UL))
  let session = Session::new(a, 0UL, SessionLimits::new())
  expect_error(() => session.receive(a, wrong_seed.encode()) |> ignore)
  stopped(session.state(), ProtocolError)
  let corrupt = Session::new(a, 0UL, SessionLimits::new())
  expect_error(() => corrupt.receive(a, b"bad") |> ignore)
  stopped(corrupt.state(), ProtocolError)
  assert_eq(corrupt.received_bytes(), 3L)
  expect_error(() => corrupt.receive(a, a.encode()) |> ignore)
}

///|
test "session replays after completion are charged without decoding again" {
  let source = Inventory::new().snapshot(Config::new(1))
  let session = Session::new(source, 0UL, SessionLimits::new(max_bytes=256L))
  session.receive(source, source.encode()) |> ignore
  session.receive(source, source.encode()) |> ignore
  assert_eq(session.rounds(), 1)
  stopped(session.receive(source, source.encode()), ByteLimit)
  assert_eq(session.received_bytes(), 384L)
}

///|
test "session limits and sent frame identity are validated" {
  expect_error(() => SessionLimits::new(max_rounds=0) |> ignore)
  expect_error(() => SessionLimits::new(max_rounds=65) |> ignore)
  expect_error(() => SessionLimits::new(max_bytes=-1L) |> ignore)
  expect_error(() => SessionLimits::new(max_bytes=1099511627777L) |> ignore)
  expect_error(() => SessionLimits::new(max_steps=1000001) |> ignore)
  expect_error(() => SessionLimits::new(max_width=0) |> ignore)
  expect_error(() => SessionLimits::new(max_members=-1) |> ignore)
  let source = Inventory::new().snapshot(Config::new(2))
  expect_error(() => {
    Session::new(source, 0UL, SessionLimits::new(max_width=1)) |> ignore
  })
  let session = Session::new(source, 0UL, SessionLimits::new())
  let changed = Inventory::new(epoch=1UL).snapshot(Config::new(2))
  stopped(session.record_sent(changed.encode()), SnapshotChanged)
  assert_eq(session.sent_bytes(), 0L)
}

///|
test "session never publishes a plan when target fingerprint verification fails" {
  let source = Inventory::new().snapshot(Config::new(1))
  let forged = { ..source, fingerprint: { count: 0, sum: 1UL, xor: 0UL, }, }
  let session = Session::new(source, 0UL, SessionLimits::new())
  expect_error(() => session.receive(source, forged.encode()) |> ignore)
  stopped(session.state(), ProtocolError)
}

///|
test "generated sessions obey cumulative work and exact-set correctness" {
  for seed = 1; seed <= 40; seed = seed + 1 {
    let a = Inventory::from_ids(Array::makei(30, fn(i) { i.to_uint64() }))
    let b = Inventory::from_ids(
      Array::makei(30, fn(i) { (i + seed % 8).to_uint64() }),
    )
    let initial = Config::new(1, seed=seed.to_uint64())
    for budget in [0, 3, 20] {
      let session = Session::new(
        a.snapshot(initial),
        0UL,
        SessionLimits::new(max_steps=budget),
      )
      for config = initial {
        let source = a.snapshot(config)
        session.record_sent(source.encode()) |> ignore
        match session.receive(source, b.snapshot(config).encode()) {
          Awaiting(next) => continue next
          Complete(plan) => {
            assert_eq(a.apply(plan).ids(), b.ids())
            break
          }
          Stopped(_) => break
        }
      }
      assert_true(session.decode_steps() <= budget)
      assert_true(session.rounds() <= 8)
      assert_true(session.sent_bytes() + session.received_bytes() <= 8388608L)
    }
  }
}
