///|
// SplitMix64 finalizer. Integer operations intentionally wrap modulo 2^64.
fn mix(value : UInt64) -> UInt64 {
  let a = (value ^ (value >> 30)) * 0xbf58476d1ce4e5b9UL
  let b = (a ^ (a >> 27)) * 0x94d049bb133111ebUL
  b ^ (b >> 31)
}

///|
fn check_key(key : UInt64, seed : UInt64) -> UInt64 {
  mix(key ^ seed ^ 0xd6e8feb86659fd93UL)
}

///|
fn positions(key : UInt64, config : Config) -> Array[Int] {
  let salts = [0x9e3779b97f4a7c15UL, 0x3c6ef372fe94f82aUL, 0xdaa66d2c7ddef743UL]
  Array::makei(3, fn(i) {
    (mix(key ^ config.seed ^ salts[i]) % config.width.to_uint64()).to_int() +
    i * config.width
  })
}

///|
fn empty_fingerprint() -> Fingerprint {
  { count: 0, sum: 0UL, xor: 0UL, }
}

///|
fn fingerprint_add(fp : Fingerprint, key : UInt64, sign : Int) -> Fingerprint {
  let h = mix(key ^ 0xa0761d6478bd642fUL)
  {
    count: fp.count + sign,
    sum: if sign == 1 {
      fp.sum + h
    } else {
      fp.sum - h
    },
    xor: fp.xor ^ mix(key ^ 0xe7037ed1a0b428dbUL),
  }
}
