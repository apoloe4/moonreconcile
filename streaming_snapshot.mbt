///|
/// Build from a strictly increasing database/index cursor without an exact Map.
/// Duplicate/order checks need O(1) state; sketch storage is O(config.width).
/// The cursor must read a consistent application snapshot throughout the scan.
pub fn Snapshot::from_sorted_ids(
  ids : Iter[UInt64],
  config : Config,
  scope? : UInt64 = 0UL,
  epoch? : UInt64 = 0UL,
  max_members? : Int = 10000000,
) -> Snapshot raise ReconcileError {
  if max_members < 0 {
    raise InvalidConfig("negative streaming member limit")
  }
  let sketch = Sketch::new(config)
  let mut fingerprint = empty_fingerprint()
  let mut previous : UInt64? = None
  for id in ids {
    if fingerprint.count >= max_members {
      raise LimitExceeded("streaming snapshot members")
    }
    if previous is Some(last) && id <= last {
      raise InvalidConfig("streaming IDs must be strictly increasing")
    }
    sketch.insert(id)
    fingerprint = fingerprint_add(fingerprint, id, 1)
    previous = Some(id)
  }
  { scope, epoch, fingerprint, sketch, }
}
