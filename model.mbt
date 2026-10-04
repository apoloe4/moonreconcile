///|
pub(all) suberror ReconcileError {
  InvalidConfig(String)
  Incompatible(String)
  InvalidFrame(String)
  LimitExceeded(String)
  StaleSnapshot
  VerificationFailed
  InvalidPlan(String)
} derive(Eq, Debug)

///|
/// Three disjoint hash bands, each of `width` cells. Immutable configuration.
pub struct Config {
  width : Int
  seed : UInt64
} derive(Eq, Debug)

///|
pub fn Config::new(
  width : Int,
  seed? : UInt64 = 1UL,
) -> Config raise ReconcileError {
  if width < 1 || width > 262144 {
    raise InvalidConfig("width must be between 1 and 262144")
  }
  { width, seed, }
}

///|
pub fn Config::width(self : Config) -> Int {
  self.width
}

///|
pub fn Config::seed(self : Config) -> UInt64 {
  self.seed
}

///|
pub fn Config::cells(self : Config) -> Int {
  self.width * 3
}

///|
/// Commutative, non-cryptographic set fingerprint. This is not authentication.
pub struct Fingerprint {
  count : Int
  sum : UInt64
  xor : UInt64
} derive(Eq, Debug)

///|
pub fn Fingerprint::count(self : Fingerprint) -> Int {
  self.count
}

///|
struct Cell {
  mut count : Int
  mut key : UInt64
  mut check : UInt64
} derive(Debug)

///|
/// Mutable algebraic sketch. Insertion/removal require valid set semantics.
/// Prefer Inventory when callers cannot guarantee uniqueness.
pub struct Sketch {
  config : Config
  cells : Array[Cell]
}

///|
/// Decode may be partial; only a complete result is a usable synchronization plan.
pub struct DecodeReport {
  positive : Array[UInt64]
  negative : Array[UInt64]
  residual : Int
  steps : Int
}

///|
pub fn DecodeReport::complete(self : DecodeReport) -> Bool {
  self.residual == 0
}

///|
pub fn DecodeReport::positive(self : DecodeReport) -> Array[UInt64] {
  self.positive.copy()
}

///|
pub fn DecodeReport::negative(self : DecodeReport) -> Array[UInt64] {
  self.negative.copy()
}

///|
pub fn DecodeReport::residual_cells(self : DecodeReport) -> Int {
  self.residual
}

///|
pub fn DecodeReport::steps(self : DecodeReport) -> Int {
  self.steps
}

///|
/// Scope separates datasets; epoch identifies an immutable snapshot version.
pub struct Snapshot {
  scope : UInt64
  epoch : UInt64
  fingerprint : Fingerprint
  sketch : Sketch
}

///|
pub fn Snapshot::scope(self : Snapshot) -> UInt64 {
  self.scope
}

///|
pub fn Snapshot::epoch(self : Snapshot) -> UInt64 {
  self.epoch
}

///|
pub fn Snapshot::fingerprint(self : Snapshot) -> Fingerprint {
  self.fingerprint
}

///|
pub fn Snapshot::config(self : Snapshot) -> Config {
  self.sketch.config
}

///|
/// Private fields prevent unvalidated plans being constructed by consumers.
pub struct Plan {
  scope : UInt64
  source_epoch : UInt64
  target_epoch : UInt64
  source : Fingerprint
  target : Fingerprint
  add : Array[UInt64]
  remove : Array[UInt64]
}

///|
pub fn Plan::additions(self : Plan) -> Array[UInt64] {
  self.add.copy()
}

///|
pub fn Plan::removals(self : Plan) -> Array[UInt64] {
  self.remove.copy()
}

///|
pub fn Plan::target_epoch(self : Plan) -> UInt64 {
  self.target_epoch
}

///|
pub enum Outcome {
  Ready(Plan)
  Retry(Config)
  FullTransfer(Int)
}

///|
pub struct Policy {
  max_width : Int
  max_differences : Int
}

///|
pub fn Policy::new(
  max_width? : Int = 65536,
  max_differences? : Int = 100000,
) -> Policy raise ReconcileError {
  if max_width < 1 ||
    max_width > 262144 ||
    max_differences < 0 ||
    max_differences > 1000000 {
    raise InvalidConfig("invalid retry or difference budget")
  }
  { max_width, max_differences, }
}
