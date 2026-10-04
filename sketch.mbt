///|
pub fn Sketch::new(config : Config) -> Sketch {
  {
    config,
    cells: Array::makei(config.cells(), fn(_) {
      { count: 0, key: 0UL, check: 0UL, }
    }),
  }
}

///|
pub fn Sketch::config(self : Sketch) -> Config {
  self.config
}

///|
pub fn Sketch::copy(self : Sketch) -> Sketch {
  {
    config: self.config,
    cells: self.cells.map(fn(c) {
      { count: c.count, key: c.key, check: c.check, }
    }),
  }
}

///|
// Validate all counters before mutation: an overflow cannot leave a partial update.
fn Sketch::update(
  self : Sketch,
  key : UInt64,
  sign : Int,
) -> Unit raise ReconcileError {
  let indexes = positions(key, self.config)
  for i in indexes {
    let count = self.cells[i].count
    if (sign == 1 && count == 2147483647) ||
      (sign == -1 && count == -2147483648) {
      raise LimitExceeded("cell counter overflow")
    }
  }
  let check = check_key(key, self.config.seed)
  for i in indexes {
    let cell = self.cells[i]
    cell.count += sign
    cell.key = cell.key ^ key
    cell.check = cell.check ^ check
  }
}

///|
pub fn Sketch::insert(self : Sketch, key : UInt64) -> Unit raise ReconcileError {
  self.update(key, 1)
}

///|
pub fn Sketch::erase(self : Sketch, key : UInt64) -> Unit raise ReconcileError {
  self.update(key, -1)
}

///|
/// Returns a new difference table, without changing either input.
pub fn Sketch::subtract(
  self : Sketch,
  other : Sketch,
) -> Sketch raise ReconcileError {
  if self.config != other.config {
    raise Incompatible("sketch width or seed mismatch")
  }
  let result = Sketch::new(self.config)
  for i = 0; i < self.cells.length(); i = i + 1 {
    let a = self.cells[i]
    let b = other.cells[i]
    let count = a.count.to_int64() - b.count.to_int64()
    if count > 2147483647L || count < -2147483648L {
      raise LimitExceeded("difference counter overflow")
    }
    result.cells[i] = {
      count: count.to_int(),
      key: a.key ^ b.key,
      check: a.check ^ b.check,
    }
  }
  result
}

///|
fn Sketch::pure(self : Sketch, i : Int) -> Bool {
  let cell = self.cells[i]
  (cell.count == 1 || cell.count == -1) &&
  cell.check == check_key(cell.key, self.config.seed) &&
  positions(cell.key, self.config).contains(i)
}

///|
/// Peels on a private copy. An explicit budget bounds work on untrusted tables.
/// The queue has at most cells + 3*budget entries; stale entries are rechecked.
pub fn Sketch::decode(
  self : Sketch,
  budget? : Int = 100000,
) -> DecodeReport raise ReconcileError {
  if budget < 0 || budget > 1000000 {
    raise InvalidConfig("invalid decode budget")
  }
  let work = self.copy()
  let queue : Array[Int] = []
  for i = 0; i < work.cells.length(); i = i + 1 {
    if work.pure(i) {
      queue.push(i)
    }
  }
  let positive : Array[UInt64] = []
  let negative : Array[UInt64] = []
  let seen : Map[UInt64, Bool] = Map([])
  let mut cursor = 0
  let mut steps = 0
  while cursor < queue.length() && steps < budget {
    let i = queue[cursor]
    cursor += 1
    if !work.pure(i) {
      continue
    }
    let cell = work.cells[i]
    let key = cell.key
    let sign = cell.count
    // A repeated key means invalid multiplicity or a forged table; retain residual.
    if seen.contains(key) {
      continue
    }
    seen[key] = true
    if sign == 1 {
      positive.push(key)
    } else {
      negative.push(key)
    }
    work.update(key, -sign)
    steps += 1
    for j in positions(key, work.config) {
      if work.pure(j) {
        queue.push(j)
      }
    }
  }
  let mut residual = 0
  for cell in work.cells {
    if cell.count != 0 || cell.key != 0UL || cell.check != 0UL {
      residual += 1
    }
  }
  positive.sort()
  negative.sort()
  { positive, negative, residual, steps, }
}
