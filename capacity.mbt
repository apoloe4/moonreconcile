///|
/// Conservative starting-size heuristic, not a probabilistic success guarantee.
/// Allocate one cell per estimated difference in each of the three bands.
pub struct CapacityPlan {
  priv initial : Config
  priv max_width : Int
}

///|
pub fn CapacityPlan::new(
  expected_differences : Int,
  max_wire_bytes? : Int = 3932228,
  seed? : UInt64 = 1UL,
) -> CapacityPlan raise ReconcileError {
  if expected_differences < 0 {
    raise InvalidConfig("negative difference estimate")
  }
  if max_wire_bytes < 128 {
    raise LimitExceeded("wire budget cannot hold a minimum sketch")
  }
  let available = (max_wire_bytes - 68) / 60
  let max_width = if available > 262144 { 262144 } else { available }
  let width = if expected_differences == 0 { 1 } else { expected_differences }
  if width > max_width {
    raise LimitExceeded("difference estimate exceeds wire budget")
  }
  { initial: Config::new(width, seed~), max_width, }
}

///|
pub fn CapacityPlan::initial(self : CapacityPlan) -> Config {
  self.initial
}

///|
/// Maximum retry width that still fits the supplied snapshot wire budget.
pub fn CapacityPlan::max_width(self : CapacityPlan) -> Int {
  self.max_width
}

///|
pub fn Config::wire_bytes(self : Config) -> Int {
  68 + self.cells() * 20
}

///|
/// Compare only summary vs raw UInt64 ID bytes, excluding protocol/payload costs.
pub fn CapacityPlan::smaller_than_full_ids(
  self : CapacityPlan,
  members : Int,
) -> Bool raise ReconcileError {
  if members < 0 {
    raise InvalidConfig("negative full-set member count")
  }
  self.initial.wire_bytes().to_int64() < members.to_int64() * 8L
}
