import Testing

/// The final step of a scenario: the context and result as verified so far, plus the full
/// narrative of how the scenario got here.
///
/// `Then<Context, Result>` only exposes `and(...)` — there is no way to go back to `when(...)`
/// or `given(...)` from here. That's deliberate: once you're asserting, the system under test
/// should no longer be mutated, and the scenario reads top-to-bottom exactly like the Given →
/// When → Then it describes.
public struct Then<Context: Sendable, Result: Sendable>: Sendable {
    /// The context as it stood when the assertions ran.
    public let context: Context

    /// The result produced by the `when` step (and any `and` chained onto it).
    public let result: Result

    let narrative: ScenarioNarrative
    let sourceLocation: SourceLocation

    /// The full, human-readable Given/When/Then transcript recorded for this scenario so far.
    /// Handy for logging or for building your own reporters.
    public var scenarioNarrative: ScenarioNarrative {
        narrative
    }
}

extension Then {
    // MARK: Closure-based assertions (native Swift Testing)

    /// Adds one more assertion after the first `then`. Use this for multiple independent
    /// `#expect`/`#require` checks so each failure is attributed to its own line.
    @discardableResult
    public func and(
        _ description: String,
        sourceLocation: SourceLocation = #_sourceLocation,
        _ assertion: (Context, Result) throws -> Void
    ) rethrows -> Then<Context, Result> {
        var narrative = narrative
        narrative.appendThen(description)
        try assertion(context, result)
        return Then(context: context, result: result, narrative: narrative, sourceLocation: sourceLocation)
    }

    /// Async counterpart of `and(_:sourceLocation:_:)`.
    @discardableResult
    public func and(
        _ description: String,
        sourceLocation: SourceLocation = #_sourceLocation,
        _ assertion: (Context, Result) async throws -> Void
    ) async rethrows -> Then<Context, Result> {
        var narrative = narrative
        narrative.appendThen(description)
        try await assertion(context, result)
        return Then(context: context, result: result, narrative: narrative, sourceLocation: sourceLocation)
    }

    // MARK: Matcher-based assertions (custom reporting)

    /// Matcher-based counterpart of `and(_:sourceLocation:_:)`. See
    /// `When.then(_:_:matches:sourceLocation:)` for the full explanation of how matcher
    /// failures are reported.
    @discardableResult
    public func and<Value>(
        _ description: String,
        _ value: (Context, Result) -> Value,
        matches matcher: Matcher<Value>,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> Then<Context, Result> {
        let narrative = recordMatcherOutcome(
            description: description,
            actual: value(context, result),
            matcher: matcher,
            narrative: narrative,
            sourceLocation: sourceLocation
        )
        return Then(context: context, result: result, narrative: narrative, sourceLocation: sourceLocation)
    }

    /// Convenience overload that reads the value straight off the result via a key path.
    @discardableResult
    public func and<Value>(
        _ description: String,
        _ keyPath: KeyPath<Result, Value>,
        matches matcher: Matcher<Value>,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> Then<Context, Result> {
        and(
            description,
            { _, result in result[keyPath: keyPath] },
            matches: matcher,
            sourceLocation: sourceLocation
        )
    }

    /// Convenience overload that reads the value off the context via a key path.
    @discardableResult
    public func and<Value>(
        _ description: String,
        context keyPath: KeyPath<Context, Value>,
        matches matcher: Matcher<Value>,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> Then<Context, Result> {
        and(
            description,
            { context, _ in context[keyPath: keyPath] },
            matches: matcher,
            sourceLocation: sourceLocation
        )
    }
}
