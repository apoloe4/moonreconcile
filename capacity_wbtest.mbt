///|
test "capacity planner respects exact wire budget and zero estimate" {
  let minimum = CapacityPlan::new(0, max_wire_bytes=128, seed=5UL)
  assert_eq(minimum.initial().width(), 1)
  assert_eq(minimum.initial().seed(), 5UL)
  assert_eq(minimum.max_width(), 1)
  assert_eq(minimum.initial().wire_bytes(), 128)
  let plan = CapacityPlan::new(20, max_wire_bytes=1288)
  assert_eq(plan.initial().wire_bytes(), 1268)
  assert_eq(plan.max_width(), 20)
  assert_eq(
    Inventory::new().snapshot(plan.initial()).encode().length(),
    plan.initial().wire_bytes(),
  )
}

///|
test "capacity planner rejects unaffordable and invalid estimates" {
  expect_error(() => CapacityPlan::new(-1) |> ignore)
  expect_error(() => CapacityPlan::new(0, max_wire_bytes=127) |> ignore)
  expect_error(() => CapacityPlan::new(2, max_wire_bytes=187) |> ignore)
  expect_error(() => {
    CapacityPlan::new(262145, max_wire_bytes=2147483647) |> ignore
  })
  assert_eq(CapacityPlan::new(1, max_wire_bytes=2147483647).max_width(), 262144)
}

///|
test "capacity byte comparison uses wide arithmetic" {
  let plan = CapacityPlan::new(0)
  assert_false(plan.smaller_than_full_ids(0))
  assert_false(plan.smaller_than_full_ids(16))
  assert_true(plan.smaller_than_full_ids(17))
  assert_true(plan.smaller_than_full_ids(2147483647))
  expect_error(() => plan.smaller_than_full_ids(-1) |> ignore)
}
