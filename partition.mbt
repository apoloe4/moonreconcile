///|
/// Hash partitioning permits exchanging sketches only for changed buckets.
/// Both peers must negotiate identical layout; seeds are not secret keys.
pub struct Layout {
  buckets : Int
  seed : UInt64
} derive(Eq, Debug)

///|
pub fn Layout::new(
  buckets : Int,
  seed? : UInt64 = 17UL,
) -> Layout raise ReconcileError {
  if buckets < 1 || buckets > 4096 {
    raise InvalidConfig("bucket count must be 1..4096")
  }
  { buckets, seed, }
}

///|
pub fn Layout::buckets(self : Layout) -> Int {
  self.buckets
}

///|
pub fn Layout::bucket(self : Layout, key : UInt64) -> Int {
  (mix(key ^ self.seed) % self.buckets.to_uint64()).to_int()
}

///|
pub struct Manifest {
  scope : UInt64
  epoch : UInt64
  layout : Layout
  total : Fingerprint
  fingerprints : Array[Fingerprint]
}

///|
pub fn Manifest::epoch(self : Manifest) -> UInt64 {
  self.epoch
}

///|
pub fn Manifest::fingerprint(self : Manifest) -> Fingerprint {
  self.total
}

///|
pub fn Inventory::manifest(self : Inventory, layout : Layout) -> Manifest {
  let fingerprints = Array::make(layout.buckets, empty_fingerprint())
  for id in self.keys.keys() {
    let bucket = layout.bucket(id)
    fingerprints[bucket] = fingerprint_add(fingerprints[bucket], id, 1)
  }
  {
    scope: self.scope,
    epoch: self.epoch,
    layout,
    total: self.fingerprint,
    fingerprints,
  }
}

///|
/// Returns changed buckets in increasing order. Fingerprints are probabilistic.
pub fn Manifest::changed_buckets(
  self : Manifest,
  remote : Manifest,
) -> Array[Int] raise ReconcileError {
  if self.scope != remote.scope || self.layout != remote.layout {
    raise Incompatible("manifest scope or partition layout mismatch")
  }
  let changed : Array[Int] = []
  for i = 0; i < self.layout.buckets; i = i + 1 {
    if self.fingerprints[i] != remote.fingerprints[i] {
      changed.push(i)
    }
  }
  changed
}

///|
pub struct BucketOffer {
  index : Int
  layout : Layout
  snapshot : Snapshot
}

///|
pub fn BucketOffer::snapshot(self : BucketOffer) -> Snapshot {
  { ..self.snapshot, sketch: self.snapshot.sketch.copy(), }
}

///|
/// Reuses a decoded snapshot; its fingerprint and routing are checked by Collector.
pub fn BucketOffer::new(
  index : Int,
  layout : Layout,
  snapshot : Snapshot,
) -> BucketOffer raise ReconcileError {
  if index < 0 || index >= layout.buckets {
    raise InvalidConfig("bucket index out of range")
  }
  { index, layout, snapshot: { ..snapshot, sketch: snapshot.sketch.copy(), }, }
}

///|
/// Single pass for one requested bucket. Calling for many buckets costs O(n*b).
/// For all-bucket exports use bucket_offers, which scans the inventory once.
pub fn Inventory::bucket_offer(
  self : Inventory,
  layout : Layout,
  index : Int,
  config : Config,
) -> BucketOffer raise ReconcileError {
  if index < 0 || index >= layout.buckets {
    raise InvalidConfig("bucket index out of range")
  }
  let sketch = Sketch::new(config)
  let mut fp = empty_fingerprint()
  for key in self.keys.keys() {
    if layout.bucket(key) == index {
      sketch.insert(key)
      fp = fingerprint_add(fp, key, 1)
    }
  }
  {
    index,
    layout,
    snapshot: { scope: self.scope, epoch: self.epoch, fingerprint: fp, sketch, },
  }
}

///|
/// Allocate only requested buckets; constrain total cells before allocating.
pub fn Inventory::bucket_offers(
  self : Inventory,
  layout : Layout,
  indexes : Array[Int],
  config : Config,
  max_cells? : Int = 1000000,
) -> Array[BucketOffer] raise ReconcileError {
  if max_cells < 0 ||
    indexes.length().to_int64() * config.cells().to_int64() >
    max_cells.to_int64() {
    raise LimitExceeded("aggregate bucket sketch allocation")
  }
  let offers : Array[BucketOffer] = []
  let lookup : Map[Int, Int] = Map([])
  for index in indexes {
    if index < 0 || index >= layout.buckets || lookup.contains(index) {
      raise InvalidConfig("duplicate or invalid bucket request")
    }
    lookup[index] = offers.length()
    offers.push({
      index,
      layout,
      snapshot: {
        scope: self.scope,
        epoch: self.epoch,
        fingerprint: empty_fingerprint(),
        sketch: Sketch::new(config),
      },
    })
  }
  let fp = Array::make(offers.length(), empty_fingerprint())
  for key in self.keys.keys() {
    if lookup.get(layout.bucket(key)) is Some(position) {
      offers[position].snapshot.sketch.insert(key)
      fp[position] = fingerprint_add(fp[position], key, 1)
    }
  }
  offers.mapi(fn(i, offer) {
    { ..offer, snapshot: { ..offer.snapshot, fingerprint: fp[i], }, }
  })
}

///|
/// Collect validated per-bucket plans in any order, with idempotent retransmits.
/// No global Plan is exposed until every changed bucket has completed.
pub struct Collector {
  source : Manifest
  target : Manifest
  pending : Array[Int]
  plans : Map[Int, Plan]
  max_changes : Int
  mut accepted_changes : Int
}

///|
pub fn Collector::new(
  source : Manifest,
  target : Manifest,
  max_changes? : Int = 100000,
) -> Collector raise ReconcileError {
  if max_changes < 0 || max_changes > 1000000 {
    raise InvalidConfig("invalid aggregate change budget")
  }
  {
    source,
    target,
    pending: source.changed_buckets(target),
    plans: Map([]),
    max_changes,
    accepted_changes: 0,
  }
}

///|
pub fn Collector::pending(self : Collector) -> Array[Int] {
  self.pending.filter(fn(i) { !self.plans.contains(i) })
}

///|
pub fn Collector::accept(
  self : Collector,
  source : BucketOffer,
  target : BucketOffer,
  policy : Policy,
) -> Outcome raise ReconcileError {
  let index = source.index
  if source.layout != self.source.layout ||
    target.layout != self.target.layout ||
    index != target.index ||
    !self.pending.contains(index) {
    raise Incompatible("unexpected bucket offer")
  }
  let a = source.snapshot
  let b = target.snapshot
  if a.scope != self.source.scope ||
    b.scope != self.target.scope ||
    a.epoch != self.source.epoch ||
    b.epoch != self.target.epoch ||
    a.fingerprint != self.source.fingerprints[index] ||
    b.fingerprint != self.target.fingerprints[index] {
    raise StaleSnapshot
  }
  let outcome = reconcile(a, b, policy)
  if outcome is Ready(plan) {
    for key in plan.add {
      if source.layout.bucket(key) != index {
        raise VerificationFailed
      }
    }
    for key in plan.remove {
      if source.layout.bucket(key) != index {
        raise VerificationFailed
      }
    }
    if self.plans.get(index) is Some(previous) {
      if previous.add != plan.add || previous.remove != plan.remove {
        raise VerificationFailed
      }
    } else {
      let changes = plan.add.length() + plan.remove.length()
      if changes > self.max_changes - self.accepted_changes {
        raise LimitExceeded("aggregate partition differences")
      }
      self.plans[index] = plan
      self.accepted_changes += changes
    }
  }
  outcome
}

///|
pub fn Collector::finish(self : Collector) -> Plan raise ReconcileError {
  if self.pending().length() != 0 {
    raise InvalidPlan("incomplete partition collection")
  }
  let add : Array[UInt64] = []
  let remove : Array[UInt64] = []
  for index in self.pending {
    if self.plans.get(index) is Some(plan) {
      for key in plan.add {
        add.push(key)
      }
      for key in plan.remove {
        remove.push(key)
      }
    }
  }
  add.sort()
  remove.sort()
  let mut expected = self.source.total
  for key in remove {
    expected = fingerprint_add(expected, key, -1)
  }
  for key in add {
    expected = fingerprint_add(expected, key, 1)
  }
  if expected != self.target.total {
    raise VerificationFailed
  }
  {
    scope: self.source.scope,
    source_epoch: self.source.epoch,
    target_epoch: self.target.epoch,
    source: self.source.total,
    target: self.target.total,
    add,
    remove,
  }
}
