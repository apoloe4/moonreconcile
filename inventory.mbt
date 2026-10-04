///|
/// Exact source set tracker: idempotent changes, immutable snapshot exports.
pub struct Inventory {
  priv scope : UInt64
  priv mut epoch : UInt64
  priv keys : Map[UInt64, Bool]
  priv mut fingerprint : Fingerprint
}

///|
pub fn Inventory::new(
  scope? : UInt64 = 0UL,
  epoch? : UInt64 = 0UL,
) -> Inventory {
  { scope, epoch, keys: Map([]), fingerprint: empty_fingerprint(), }
}

///|
/// Initial duplicates are discarded. All UInt64 values, including zero, are valid IDs.
pub fn Inventory::from_ids(
  ids : Array[UInt64],
  scope? : UInt64 = 0UL,
  epoch? : UInt64 = 0UL,
) -> Inventory {
  let inventory = Inventory::new(scope~, epoch~)
  for id in ids {
    if !inventory.keys.contains(id) {
      inventory.keys[id] = true
      inventory.fingerprint = fingerprint_add(inventory.fingerprint, id, 1)
    }
  }
  inventory
}

///|
pub fn Inventory::contains(self : Inventory, id : UInt64) -> Bool {
  self.keys.contains(id)
}

///|
pub fn Inventory::epoch(self : Inventory) -> UInt64 {
  self.epoch
}

///|
pub fn Inventory::fingerprint(self : Inventory) -> Fingerprint {
  self.fingerprint
}

///|
pub fn Inventory::ids(self : Inventory) -> Array[UInt64] {
  let ids = self.keys.keys().to_array()
  ids.sort()
  ids
}

///|
pub fn Inventory::insert(
  self : Inventory,
  id : UInt64,
) -> Bool raise ReconcileError {
  if self.keys.contains(id) {
    return false
  }
  if self.epoch == 0xffffffffffffffffUL || self.fingerprint.count == 2147483647 {
    raise LimitExceeded("inventory version or size overflow")
  }
  self.keys[id] = true
  self.fingerprint = fingerprint_add(self.fingerprint, id, 1)
  self.epoch += 1UL
  true
}

///|
pub fn Inventory::remove(
  self : Inventory,
  id : UInt64,
) -> Bool raise ReconcileError {
  if !self.keys.contains(id) {
    return false
  }
  if self.epoch == 0xffffffffffffffffUL {
    raise LimitExceeded("inventory version overflow")
  }
  self.keys.remove(id)
  self.fingerprint = fingerprint_add(self.fingerprint, id, -1)
  self.epoch += 1UL
  true
}

///|
pub fn Inventory::snapshot(
  self : Inventory,
  config : Config,
) -> Snapshot raise ReconcileError {
  let sketch = Sketch::new(config)
  for id in self.keys.keys() {
    sketch.insert(id)
  }
  {
    scope: self.scope,
    epoch: self.epoch,
    fingerprint: self.fingerprint,
    sketch,
  }
}

///|
/// Atomically applies a plan to a copy, so failures never alter the source.
/// This transfers IDs only. Applications fetch/authenticate payloads separately.
pub fn Inventory::apply(
  self : Inventory,
  plan : Plan,
) -> Inventory raise ReconcileError {
  if self.scope != plan.scope ||
    self.epoch != plan.source_epoch ||
    self.fingerprint != plan.source {
    raise StaleSnapshot
  }
  let result = Inventory::from_ids(
    self.ids(),
    scope=self.scope,
    epoch=plan.target_epoch,
  )
  for id in plan.remove {
    if !result.keys.contains(id) {
      raise InvalidPlan("removal missing from source")
    }
    result.keys.remove(id)
    result.fingerprint = fingerprint_add(result.fingerprint, id, -1)
  }
  for id in plan.add {
    if result.keys.contains(id) {
      raise InvalidPlan("addition already exists")
    }
    result.keys[id] = true
    result.fingerprint = fingerprint_add(result.fingerprint, id, 1)
  }
  if result.fingerprint != plan.target {
    raise VerificationFailed
  }
  result
}
