import Testing

/// The second step of a scenario: the context as it stood right after the action under test
/// ran, plus whatever that action produced.
///
/// `When<Context, Result>` only exposes `and(...)` (to chain further actions) and `then(...)`
/// (to move on to assertions). It has no `given`/`and`-setup members, so you cannot go back to
/// building the fixture once you've started exercising it — that transition is a compile error.
public struct When<Context: Sendable, Result: Sendable>: Sendable {
    /// The context as of the most recent `when`/`and` step.
    public let context: Context

    /// What the most recent action produced.
    public let result: Result

    let narrative: ScenarioNarrative
    let sourceLocation: SourceLocation
}

extension When {
    /// Chains another action, e.g. a second event in a multi-step workflow. Receives both the
    /// context (mutable, in case this action has side effects too) and the previous result.
    public func and<NewResult: Sendable>(
        _ description: String,
        sourceLocation: SourceLocation = #_sourceLocation,
        _ action: (inout Context, Result) throws -> NewResult
    ) rethrows -> When<Context, NewResult> {
        var context = context
        let newResult = try action(&context, result)
        var narrative = narrative
        narrative.appendWhen(description)
        return When<Context, NewResult>(
            context: context,
            result: newResult,
            narrative: narrative,
            sourceLocation: sourceLocation
        )
    }

    /// Async counterpart of `and(_:sourceLocation:_:)`.
    public func and<NewResult: Sendable>(
        _ description: String,
        sourceLocation: SourceLocation = #_sourceLocation,
        _ action: (inout Context, Result) async throws -> NewResult
    ) async rethrows -> When<Context, NewResult> {
        var context = context
        let newResult = try await action(&context, result)
        var narrative = narrative
        narrative.appendWhen(description)
        return When<Context, NewResult>(
            context: context,
            result: newResult,
            narrative: narrative,
            sourceLocation: sourceLocation
        )
    }

    // MARK: Closure-based assertions (native Swift Testing)

    /// Moves to the `Then` step by running an assertion closure. Write ordinary `#expect`/
    /// `#require` calls inside — they report through Swift Testing exactly as if they were
    /// written directly in the test body, with correct file/line attribution, because the
    /// macro expansion happens at the call site you wrote, not inside this library.
    ///
    /// Deliberately read-only: the closure receives `Context` (not `inout Context`), so
    /// assertions can't accidentally mutate the system under test.
    @discardableResult
    public func then(
        _ description: String,
        sourceLocation: SourceLocation = #_sourceLocation,
        _ assertion: (Context, Result) throws -> Void
    ) rethrows -> Then<Context, Result> {
        var narrative = narrative
        narrative.appendThen(description)
        try assertion(context, result)
        return Then(context: context, result: result, narrative: narrative, sourceLocation: sourceLocation)
    }

    /// Async counterpart of `then(_:sourceLocation:_:)`.
    @discardableResult
    public func then(
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

    /// Verifies a value derived from the context and/or result against a ``Matcher``. On
    /// mismatch, this reports through the active ``ScenarioReporter`` (by default,
    /// `Issue.record`) with a message that includes the full scenario narrative — useful when
    /// the failure needs to explain *how* the system got into the bad state, not just that it
    /// did.
    @discardableResult
    public func then<Value>(
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
    public func then<Value>(
        _ description: String,
        _ keyPath: KeyPath<Result, Value>,
        matches matcher: Matcher<Value>,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> Then<Context, Result> {
        then(
            description,
            { _, result in result[keyPath: keyPath] },
            matches: matcher,
            sourceLocation: sourceLocation
        )
    }

    /// Convenience overload that reads the value off the context via a key path — useful for
    /// asserting on a collaborator deep in an object graph (e.g. `\.ledger.reservations.count`).
    @discardableResult
    public func then<Value>(
        _ description: String,
        context keyPath: KeyPath<Context, Value>,
        matches matcher: Matcher<Value>,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> Then<Context, Result> {
        then(
            description,
            { context, _ in context[keyPath: keyPath] },
            matches: matcher,
            sourceLocation: sourceLocation
        )
    }
}
