///|
/// Reconcile source -> remote. A Retry means both peers must rebuild summaries
/// at the returned configuration for the same frozen snapshots.
pub fn reconcile(
  source : Snapshot,
  remote : Snapshot,
  policy : Policy,
) -> Outcome raise ReconcileError {
  if source.scope != remote.scope {
    raise Incompatible("dataset scope mismatch")
  }
  if source.config() != remote.config() {
    raise Incompatible("sketch configuration mismatch")
  }
  let config = source.config()
  if config.width > policy.max_width {
    raise LimitExceeded("snapshot exceeds policy width")
  }
  let difference = remote.sketch.subtract(source.sketch)
  let report = difference.decode(budget=policy.max_differences)
  if report.complete() {
    let mut expected = source.fingerprint
    for id in report.negative {
      expected = fingerprint_add(expected, id, -1)
    }
    for id in report.positive {
      expected = fingerprint_add(expected, id, 1)
    }
    if expected != remote.fingerprint {
      raise VerificationFailed
    }
    Ready({
      scope: source.scope,
      source_epoch: source.epoch,
      target_epoch: remote.epoch,
      source: source.fingerprint,
      target: remote.fingerprint,
      add: report.positive.copy(),
      remove: report.negative.copy(),
    })
  } else if config.width < policy.max_width &&
    report.steps < policy.max_differences {
    let width = if config.width * 2 > policy.max_width {
      policy.max_width
    } else {
      config.width * 2
    }
    Retry(Config::new(width, seed=config.seed))
  } else {
    FullTransfer(report.residual)
  }
}

///|
/// Convenience for source simulations. Network applications should call reconcile
/// on received frames, send Retry requests, and implement their own transport.
pub fn synchronize(
  source : Inventory,
  remote : Inventory,
  initial : Config,
  policy : Policy,
) -> Outcome raise ReconcileError {
  for config = initial {
    match reconcile(source.snapshot(config), remote.snapshot(config), policy) {
      Retry(next) => continue next
      outcome => break outcome
    }
  }
}
