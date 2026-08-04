import Testing

/// The first step of a scenario: an immutable snapshot of everything that has been set up so
/// far, plus the narrative of how it got there.
///
/// `Given<Context>` only exposes `and(...)` (to keep building up the fixture) and `when(...)`
/// (to move on to the action under test). It deliberately has **no** `then`/`and`-with-matcher
/// members, so writing `given(...).then(...)` is a compile error, not a runtime one — the
/// Given → When → Then sequence is enforced by the type checker, not by convention.
public struct Given<Context: Sendable>: Sendable {
    /// The fixture built up so far — your system under test plus its collaborators.
    public let context: Context

    let narrative: ScenarioNarrative
    let sourceLocation: SourceLocation

    /// Starts a new scenario from a context value you've already constructed.
    ///
    /// - Parameters:
    ///   - description: A short, present-tense description of the starting state, e.g.
    ///     `"a checkout fixture with an empty cart"`. Shown as the first line of the scenario
    ///     narrative in any failure report.
    ///   - sourceLocation: Captured automatically — you should not need to pass this yourself.
    ///   - context: The initial fixture/system-under-test.
    public init(
        _ description: String = "the initial context",
        sourceLocation: SourceLocation = #_sourceLocation,
        context: Context
    ) {
        self.context = context
        self.sourceLocation = sourceLocation
        var narrative = ScenarioNarrative()
        narrative.appendGiven(description)
        self.narrative = narrative
    }

    init(context: Context, narrative: ScenarioNarrative, sourceLocation: SourceLocation) {
        self.context = context
        self.narrative = narrative
        self.sourceLocation = sourceLocation
    }
}

extension Given {
    /// Adds another setup step, mutating the context in place. Chain as many of these as you
    /// need to assemble a complex object graph — each call narrates one more `And ...` line.
    ///
    /// ```swift
    /// given("a checkout fixture") { CheckoutFixture() }
    ///     .and("two espressos are added to the cart") { fixture in
    ///         fixture.cart.add(espresso, quantity: 2)
    ///     }
    /// ```
    public func and(
        _ description: String,
        sourceLocation: SourceLocation = #_sourceLocation,
        _ mutate: (inout Context) throws -> Void
    ) rethrows -> Given<Context> {
        var context = context
        try mutate(&context)
        var narrative = narrative
        narrative.appendGiven(description)
        return Given(context: context, narrative: narrative, sourceLocation: sourceLocation)
    }

    /// Async counterpart of `and(_:sourceLocation:_:)`, for setup that needs to await
    /// something (e.g. seeding a database or warming a cache).
    public func and(
        _ description: String,
        sourceLocation: SourceLocation = #_sourceLocation,
        _ mutate: (inout Context) async throws -> Void
    ) async rethrows -> Given<Context> {
        var context = context
        try await mutate(&context)
        var narrative = narrative
        narrative.appendGiven(description)
        return Given(context: context, narrative: narrative, sourceLocation: sourceLocation)
    }

    /// Moves to the `When` step by performing the action under test and capturing its result.
    /// The action receives the context as `inout` so it may also record side effects (e.g. an
    /// event log) as part of exercising the system.
    public func when<Result: Sendable>(
        _ description: String,
        sourceLocation: SourceLocation = #_sourceLocation,
        _ action: (inout Context) throws -> Result
    ) rethrows -> When<Context, Result> {
        var context = context
        let result = try action(&context)
        var narrative = narrative
        narrative.appendWhen(description)
        return When(context: context, result: result, narrative: narrative, sourceLocation: sourceLocation)
    }

    /// Async counterpart of `when(_:sourceLocation:_:)`.
    public func when<Result: Sendable>(
        _ description: String,
        sourceLocation: SourceLocation = #_sourceLocation,
        _ action: (inout Context) async throws -> Result
    ) async rethrows -> When<Context, Result> {
        var context = context
        let result = try await action(&context)
        var narrative = narrative
        narrative.appendWhen(description)
        return When(context: context, result: result, narrative: narrative, sourceLocation: sourceLocation)
    }
}

/// Entry point for a scenario: builds the initial context and wraps it in a ``Given``.
///
/// ```swift
/// @Test
/// func checkoutAppliesDiscount() throws {
///     try given("a checkout fixture with an empty cart") {
///         CheckoutFixture(cart: Cart(), ledger: InventoryLedger(), pricing: PricingEngine())
///     }
///     .and("two espressos are added to the cart") { fixture in
///         fixture.cart.add(espresso, quantity: 2)
///     }
///     .when("the cart is checked out") { fixture in
///         try fixture.service.checkout(fixture.cart)
///     }
///     .then("the receipt total reflects a 10% discount") { _, receipt in
///         #expect(receipt.total == Decimal(string: "8.775")!)
///     }
/// }
/// ```
public func given<Context: Sendable>(
    _ description: String = "the initial context",
    sourceLocation: SourceLocation = #_sourceLocation,
    _ build: () throws -> Context
) rethrows -> Given<Context> {
    try Given(description, sourceLocation: sourceLocation, context: build())
}

/// Async counterpart of `given(_:sourceLocation:_:)`.
public func given<Context: Sendable>(
    _ description: String = "the initial context",
    sourceLocation: SourceLocation = #_sourceLocation,
    _ build: () async throws -> Context
) async rethrows -> Given<Context> {
    try await Given(description, sourceLocation: sourceLocation, context: build())
}

/// Value-based convenience for when the context is already built (no closure needed).
public func given<Context: Sendable>(
    _ description: String = "the initial context",
    sourceLocation: SourceLocation = #_sourceLocation,
    context: Context
) -> Given<Context> {
    Given(description, sourceLocation: sourceLocation, context: context)
}
