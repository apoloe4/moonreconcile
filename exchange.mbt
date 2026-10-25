///|
/// Limits apply to one observer's actual sent+received MRCL frames, across retries.
/// Transport headers, payload downloads and full-transfer fallback are separate.
pub struct SessionLimits {
  priv max_rounds : Int
  priv max_bytes : Int64
  priv max_steps : Int
  priv max_width : Int
  priv max_members : Int
}

///|
pub fn SessionLimits::new(
  max_rounds? : Int = 8,
  max_bytes? : Int64 = 8388608L,
  max_steps? : Int = 100000,
  max_width? : Int = 65536,
  max_members? : Int = 10000000,
) -> SessionLimits raise ReconcileError {
  // A 1 TiB ceiling leaves ample Int64 headroom even for an over-budget frame.
  if max_rounds < 1 ||
    max_rounds > 64 ||
    max_bytes < 0L ||
    max_bytes > 1099511627776L ||
    max_steps < 0 ||
    max_steps > 1000000 ||
    max_width < 1 ||
    max_width > 262144 ||
    max_members < 0 {
    raise InvalidConfig("invalid session limits")
  }
  { max_rounds, max_bytes, max_steps, max_width, max_members, }
}

///|
pub enum SessionStop {
  ByteLimit
  RoundLimit
  WorkLimit
  WidthLimit
  SnapshotChanged
  ProtocolError
} derive(Eq, Debug)

///|
pub fn SessionStop::label(self : SessionStop) -> String {
  match self {
    ByteLimit => "byte_limit"
    RoundLimit => "round_limit"
    WorkLimit => "work_limit"
    WidthLimit => "width_limit"
    SnapshotChanged => "snapshot_changed"
    ProtocolError => "protocol_error"
  }
}

///|
pub enum SessionState {
  Awaiting(Config)
  Complete(Plan)
  Stopped(SessionStop)
}

///|
/// Transport-neutral observer. Each session binds one frozen source and target
/// epoch. Source snapshots passed on later rounds must retain the same identity.
/// Accepted frames are retained for exact replay detection, bounded by max_bytes.
pub struct Session {
  priv limits : SessionLimits
  priv scope : UInt64
  priv source_epoch : UInt64
  priv source_fingerprint : Fingerprint
  priv target_epoch : UInt64
  priv seed : UInt64
  priv mut target_fingerprint : Fingerprint?
  priv mut state : SessionState
  priv frames : Array[Bytes]
  priv mut rounds : Int
  priv mut sent : Int64
  priv mut received : Int64
  priv mut steps : Int
}

///|
pub fn Session::new(
  source : Snapshot,
  target_epoch : UInt64,
  limits : SessionLimits,
) -> Session raise ReconcileError {
  if source.config().width > limits.max_width ||
    source.fingerprint.count > limits.max_members {
    raise LimitExceeded("source exceeds session limits")
  }
  {
    limits,
    scope: source.scope,
    source_epoch: source.epoch,
    source_fingerprint: source.fingerprint,
    target_epoch,
    seed: source.config().seed,
    target_fingerprint: None,
    state: Awaiting(source.config()),
    frames: [],
    rounds: 0,
    sent: 0L,
    received: 0L,
    steps: 0,
  }
}

///|
pub fn Session::state(self : Session) -> SessionState {
  self.state
}

///|
pub fn Session::rounds(self : Session) -> Int {
  self.rounds
}

///|
pub fn Session::sent_bytes(self : Session) -> Int64 {
  self.sent
}

///|
pub fn Session::received_bytes(self : Session) -> Int64 {
  self.received
}

///|
pub fn Session::decode_steps(self : Session) -> Int {
  self.steps
}

///|
fn Session::source_matches(self : Session, source : Snapshot) -> Bool {
  source.scope == self.scope &&
  source.epoch == self.source_epoch &&
  source.fingerprint == self.source_fingerprint &&
  source.config().seed == self.seed
}

///|
fn Session::stop(self : Session, reason : SessionStop) -> SessionState {
  self.state = Stopped(reason)
  self.state
}

///|
/// Call immediately BEFORE sending a local snapshot. A returned Stopped means
/// do not send it. Retransmissions are charged again. This does not perform IO.
pub fn Session::record_sent(
  self : Session,
  frame : Bytes,
) -> SessionState raise ReconcileError {
  match self.state {
    Awaiting(_) => ()
    _ => raise InvalidPlan("session is terminal")
  }
  errdefer self.stop(ProtocolError) |> ignore
  if frame.length().to_int64() >
    self.limits.max_bytes - self.sent - self.received {
    return self.stop(ByteLimit)
  }
  let source = Snapshot::decode(
    frame,
    DecodeLimits::new(
      max_width=self.limits.max_width,
      max_members=self.limits.max_members,
    ),
  )
  if !self.source_matches(source) {
    return self.stop(SnapshotChanged)
  }
  match self.state {
    Awaiting(config) =>
      if source.config() != config {
        self.stop(ProtocolError) |> ignore
        raise Incompatible("sent snapshot configuration")
      }
    _ => ()
  }
  self.sent += frame.length().to_int64()
  self.state
}

///|
/// Every call accounts actual received bytes, even malformed/duplicate frames.
/// Stopped sessions reject further input. Exact accepted replays do not consume
/// additional decode rounds/steps. Errors terminally invalidate the session.
pub fn Session::receive(
  self : Session,
  source : Snapshot,
  frame : Bytes,
) -> SessionState raise ReconcileError {
  match self.state {
    Stopped(_) => raise InvalidPlan("session is stopped")
    _ => ()
  }
  errdefer self.stop(ProtocolError) |> ignore
  self.received += frame.length().to_int64()
  if self.received > self.limits.max_bytes - self.sent {
    return self.stop(ByteLimit)
  }
  if !self.source_matches(source) {
    return self.stop(SnapshotChanged)
  }
  // Exact equality prevents a checksum collision from masquerading as a replay.
  if self.frames.contains(frame) {
    return self.state
  }
  let config = match self.state {
    Awaiting(config) => config
    _ => {
      self.stop(ProtocolError) |> ignore
      raise Incompatible("unexpected new frame after completion")
    }
  }
  if source.config() != config {
    self.stop(ProtocolError) |> ignore
    raise Incompatible("local snapshot configuration")
  }
  let remote = Snapshot::decode(
    frame,
    DecodeLimits::new(
      max_width=self.limits.max_width,
      max_members=self.limits.max_members,
    ),
  )
  if remote.scope != self.scope || remote.epoch != self.target_epoch {
    return self.stop(SnapshotChanged)
  }
  if remote.config() != config {
    self.stop(ProtocolError) |> ignore
    raise Incompatible("received snapshot configuration")
  }
  match self.target_fingerprint {
    Some(fp) =>
      if fp != remote.fingerprint {
        return self.stop(SnapshotChanged)
      }
    None => self.target_fingerprint = Some(remote.fingerprint)
  }
  if self.rounds >= self.limits.max_rounds {
    return self.stop(RoundLimit)
  }
  self.rounds += 1
  let remaining = self.limits.max_steps - self.steps
  let report = remote.sketch.subtract(source.sketch).decode(budget=remaining)
  self.steps += report.steps
  self.frames.push(frame)
  if report.complete() {
    let plan = validated_plan(source, remote, report)
    self.state = Complete(plan)
  } else if self.steps >= self.limits.max_steps {
    return self.stop(WorkLimit)
  } else if self.rounds >= self.limits.max_rounds {
    return self.stop(RoundLimit)
  } else if config.width >= self.limits.max_width {
    return self.stop(WidthLimit)
  } else {
    let width = if config.width * 2 > self.limits.max_width {
      self.limits.max_width
    } else {
      config.width * 2
    }
    self.state = Awaiting(Config::new(width, seed=self.seed))
  }
  self.state
}
