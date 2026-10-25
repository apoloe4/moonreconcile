///|
fn exchange(name : String, width : Int32, max_bytes : Int64) -> Unit raise {
  let source = @reconcile.Inventory::from_ids(
    [0UL, 1UL, 2UL],
    scope=42UL,
    epoch=7UL,
  )
  let target = @reconcile.Inventory::from_ids(
    [3UL, 4UL, 5UL],
    scope=42UL,
    epoch=9UL,
  )
  let initial = @reconcile.Config::new(width)
  let session = @reconcile.Session::new(
    source.snapshot(initial),
    target.epoch(),
    @reconcile.SessionLimits::new(max_bytes~),
  )
  // These two queues stand in for an application's transport adapter. Both
  // directions carry actual encoded frames, not an estimate of snapshot size.
  let outbound : Array[Bytes] = []
  let inbound : Array[Bytes] = []
  for config = initial {
    let frozen = source.snapshot(config)
    let request = frozen.encode()
    match session.record_sent(request) {
      Stopped(reason) => {
        println("\{name}: fallback=\{reason.label()}")
        break
      }
      _ => ()
    }
    outbound.push(request)
    let received_by_peer = @reconcile.Snapshot::decode(
      outbound.remove(0),
      @reconcile.DecodeLimits::new(),
    )
    assert_eq(received_by_peer.config(), config)
    inbound.push(target.snapshot(received_by_peer.config()).encode())
    match session.receive(frozen, inbound.remove(0)) {
      Complete(plan) => {
        assert_eq(source.apply(plan).ids(), target.ids())
        println("\{name}: verified exact target")
        break
      }
      Awaiting(next) => continue next
      Stopped(reason) => {
        println("\{name}: fallback=\{reason.label()}")
        break
      }
    }
  }
  println(
    "rounds=\{session.rounds()}, sent=\{session.sent_bytes()}, received=\{session.received_bytes()}, steps=\{session.decode_steps()}",
  )
  match (name, session.state()) {
    ("first", Complete(_)) => assert_eq(session.rounds(), 1)
    ("retry", Complete(_)) => assert_true(session.rounds() > 1)
    ("budget", Stopped(ByteLimit)) => assert_eq(session.sent_bytes(), 128L)
    _ => fail("unexpected example outcome")
  }
}

///|
fn main {
  try {
    exchange("first", 16, 100000L)
    exchange("retry", 1, 100000L)
    exchange("budget", 1, 256L)
  } catch {
    e => abort(e.to_string())
  }
}
