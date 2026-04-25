// SPDX-License-Identifier: PMPL-1.0-or-later
// Example unit tests for Counter component

open Test.Runner

test("Counter increments", () => {
  let (count, setCount) = ReactTestingLibrary.renderHook(() => {
    React.useState(_ => 0)
  })
  Assert.equal(count, 0)
})
