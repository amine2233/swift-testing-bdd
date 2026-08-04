# SwiftTestingBDD

A fluent, chained Given/When/Then DSL for [Swift Testing](https://developer.apple.com/documentation/testing) that enforces the BDD sequence **at the type level** — `Given` can only lead to `When`, and `When` can only lead to `Then`. Skipping a step, or going backwards, is a compile error, not a test failure you discover at runtime.

```swift
import Testing
import SwiftTestingBDD

@Test("Checking out a cart with a valid discount code reserves inventory and applies 10% off")
func checkoutAppliesDiscountAndReservesInventory() throws {
    try given("a checkout fixture with an empty cart") {
        CheckoutFixture.makeEmpty()
    }
    .and("two espressos are added to the cart") { fixture in
        fixture.cart.add(espresso, quantity: 2)
    }
    .and("a WELCOME10 discount code is applied") { fixture in
        fixture.cart.discountCode = "WELCOME10"
    }
    .when("the cart is checked out") { fixture in
        try fixture.service.checkout(fixture.cart)
    }
    .then("the receipt total reflects a 10% discount") { _, receipt in
        #expect(receipt.total == Decimal(string: "8.775")!)
    }
    .and("the espresso SKU was reserved", \.reservedSKUs, matches: .contain("ESP-001"))
}
```

## Installation

Add this package to your Package.swift as dependency and to your target.

```swift
dependencies: [
    .package(
        url: "https://github.com/amine2233/swift-testing-bdd.git",
        from: "1.0.0"
    )
],
targets: [
    .testTarget(name: "AppTests", dependencies: [
        .product(name: "SwiftTestingBDD", package: "swift-testing-bdd"),
    ]),
]
```

Import in your code

```swift
import SwiftTestingBDD
```

`SwiftTestingBDD` imports `Testing` directly (not only in its own test target) so it can bridge matcher failures into `Issue.record`. On a Swift 6+ toolchain (Xcode 16+, or `swift.org` 6.x on Linux), `Testing` ships with the toolchain itself and needs no extra dependency — which is exactly what this package assumes.

## Why type-level enforcement

`Given<Context>`, `When<Context, Result>`, and `Then<Context, Result>` are three distinct types, each exposing only the methods that make sense for that step:

| Type | Exposes | Does **not** expose |
|---|---|---|
| `Given<Context>` | `and(...)`, `when(...)` | `then`, `and(matches:)` |
| `When<Context, Result>` | `and(...)`, `then(...)` | `given`, no way back |
| `Then<Context, Result>` | `and(...)` | `when`, `given`, no way back |

Because of this, the following don't compile — they're rejected by the compiler before the test even builds:

```swift
let step = given("a cart") { Cart() }
step.then { _, _ in }     // ❌ value of type 'Given<Cart>' has no member 'then'

let outcome = step.when("it is emptied") { $0.lines.removeAll() }
outcome.given { Cart() }  // ❌ value of type 'When<Cart, Void>' has no member 'given'
```

## Two ways to assert, one narrative

**1. Closure-based `then`/`and` — full native Swift Testing power.**
Write ordinary `#expect`/`#require` calls inside. Because the macro expansion happens at the exact call site you wrote it, file/line attribution, rich value diffing, and `#require`'s test-aborting behavior all work exactly as if you'd written the check directly in the test body.

```swift
.then("the total is correct") { context, receipt in
    #expect(receipt.total == expectedTotal)
    #expect(context.ledger.reservations.count == 2)
}
```

**2. Matcher-based `then`/`and` — for reusable, named expectations with custom reporting.**
`Matcher<Value>` is a small, composable predicate type (`.equal(_:)`, `.notEqual(_:)`, `.contain(_:)`, `.beEmpty`, `.beNotEmpty`, `.haveCount(_:)`, `.beGreaterThan(_:)`, `.be(in:)`, `.beNil()`, `.beSome(matching:)`, `.satisfy(_:_:)`, `&&`, `||`, `!`, `.pullback(_:)`). Failures go through the pluggable `ScenarioReporter` protocol (default: `SwiftTestingReporter`, which calls `Issue.record` under the hood) with the **entire scenario narrative** attached, so a failure reads like the whole story, not just the final check:

```swift
.then("the espresso SKU was reserved", \.reservedSKUs, matches: .contain("ESP-001"))
.and("exactly two SKUs were reserved", context: \.ledger.reservations.count, matches: .equal(2))
```

A failing matcher produces something like:

```
Expected the espresso SKU was reserved to be contain ESP-001, but found [].

Scenario so far:
Given a checkout fixture with an empty cart
And two espressos are added to the cart
And a WELCOME10 discount code is applied
When the cart is checked out
Then the espresso SKU was reserved
```

Both styles compose in the same chain — mix and match per assertion.

## Custom reporting

`ScenarioReporter` is a plain protocol:

```swift
public protocol ScenarioReporter: Sendable {
    func reportFailure(_ failure: ScenarioFailure)
}
```

Swap in your own to log failures elsewhere, feed a custom test dashboard, or capture failures for meta-testing your own matchers, using the task-local `withScenarioReporter`:

```swift
final class RecordingReporter: ScenarioReporter, @unchecked Sendable {
    private(set) var failures: [ScenarioFailure] = []
    func reportFailure(_ failure: ScenarioFailure) { failures.append(failure) }
}

let reporter = RecordingReporter()
withScenarioReporter(reporter) {
    given("a value") { 1 }
        .when("it is doubled") { $0 * 2 }
        .then("it is wrongly expected to be 3", \.self, matches: .equal(3))
}
#expect(reporter.failures.count == 1)
```

A `@TaskLocal` (not a global) backs the active reporter, so overrides scoped in one test never leak into another test running concurrently — Swift Testing parallelizes by default. `withScenarioReporter` has sync and async forms.

## Object graphs and service layers

`Context` is just a value (or a struct wrapping several collaborators), so it scales naturally to multi-collaborator service layers. Bundle everything the scenario needs into one fixture type:

```swift
struct CheckoutFixture: Sendable {
    var cart: Cart
    let ledger: InventoryLedger      // a repository-like collaborator
    let pricing: PricingEngine       // a pure calculation collaborator
    var service: CheckoutService { CheckoutService(ledger: ledger, pricing: pricing) }
}
```

`Given.and(...)` and `Given.when(...)` receive the context as `inout`, so incremental setup across several `and` calls reads naturally for value-type fixtures, while class-based collaborators (like a mutable ledger) work the same way through their reference semantics. Assertions (`then`/`and`) are deliberately **read-only** — they receive `Context` without `inout` — so verification can never accidentally mutate the system under test.

Key-path convenience overloads let you assert on the result *or* reach into the context to check any collaborator, however deep:

```swift
.then("the total is discounted", \.total, matches: .equal(expected))
.and("inventory was reserved", context: \.ledger.reservations.count, matches: .equal(2))
```

## Async and throwing support

Every step has sync and async, throwing and non-throwing forms. Just write `await`/`try` where you need them — the right overload is picked automatically:

```swift
try await given("a warmed-up cache") {
    await CacheFixture.seeded()
}
.and("a background refresh completes") { fixture in
    try await fixture.cache.refresh()
}
.when("a value is requested") { fixture in
    try await fixture.cache.value(for: "key")
}
.then("it came from the warm cache") { context, value in
    #expect(context.cache.hitCount == 1)
    #expect(value == "expected-value")
}
```

## Requirements

- Swift 6.0+ toolchain
- macOS 10.15+ / iOS 13+ deployment targets, or Linux with a Swift 6 toolchain

## Design notes

- **Value semantics throughout.** `Given`, `When`, and `Then` are all `Sendable` structs; each step returns a new instance rather than mutating shared state, so a scenario is safe to reason about even under Swift Testing's parallel-by-default execution.
- **No macros of our own.** The DSL is plain generic structs and functions — it leans entirely on Swift's existing `#expect`/`#require` macros for the closure-based path, and on ordinary `Issue.record` for the matcher-based path. This keeps the library simple to read, debug, and extend, and avoids taking on macro-plugin build complexity for a feature Swift Testing already provides.
- **`inout` for actions, not assertions.** `Given.and`/`Given.when`/`When.and` take `Context` as `inout` because setup and the action under test are allowed to change state. `When.then`/`Then.and` take `Context` as a plain (non-`inout`) parameter, because assertions should only observe, never mutate — enforced by the compiler, not a code-review convention.

## License

See [License](License).
