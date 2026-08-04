import Testing

/// A pluggable sink for failures produced by the matcher-based (`matches:`) side of the DSL.
///
/// The default reporter (``SwiftTestingReporter``) forwards every failure to
/// `Issue.record(_:sourceLocation:)`, so it shows up exactly like a normal `#expect` failure in
/// Xcode, `swift test`, and CI. Provide your own conformance to also log to a file, ship
/// failures to a dashboard, collect them for a custom test report, or implement "soft
/// assertions" that record every mismatch in a scenario before failing once at the end.
///
/// Conform to `Sendable` because Swift Testing may run tests concurrently — reporters must be
/// safe to use from multiple tasks.
public protocol ScenarioReporter: Sendable {
    func reportFailure(_ failure: ScenarioFailure)
}

/// The default ``ScenarioReporter``, which bridges directly into Swift Testing's own issue
/// tracking via `Issue.record(_:sourceLocation:)`. This is what makes matcher failures appear
/// side-by-side with ordinary `#expect` failures in tests, Xcode's Test Navigator, and any CI
/// system that consumes Swift Testing's output.
public struct SwiftTestingReporter: ScenarioReporter {
    public init() {}

    public func reportFailure(_ failure: ScenarioFailure) {
        Issue.record("\(failure.description)", sourceLocation: failure.sourceLocation)
    }
}

/// Namespace for the task-local ``ScenarioReporter`` used by the matcher-based `then`/`and`
/// overloads.
///
/// A `@TaskLocal` (rather than a global `var`) is used deliberately: Swift Testing executes
/// tests concurrently by default, so scoping the active reporter to the current task tree keeps
/// reporter overrides in one test from leaking into another that happens to run in parallel.
public enum ScenarioReporting {
    @TaskLocal public static var current: any ScenarioReporter = SwiftTestingReporter()
}

/// Runs `operation` with `reporter` installed as the active ``ScenarioReporter`` for the
/// duration of the call (and any tasks it awaits into). Use this to capture failures for
/// inspection (e.g. in a meta-test of your own custom matchers) or to route failures somewhere
/// other than Swift Testing's default issue stream.
///
/// ```swift
/// final class RecordingReporter: ScenarioReporter, @unchecked Sendable {
///     private(set) var failures: [ScenarioFailure] = []
///     func reportFailure(_ failure: ScenarioFailure) { failures.append(failure) }
/// }
///
/// let reporter = RecordingReporter()
/// withScenarioReporter(reporter) {
///     given("a value") { 1 }
///         .when("it is doubled") { $0 * 2 }
///         .then("it is wrongly expected to be 3", \.self, matches: .equal(3))
/// }
/// #expect(reporter.failures.count == 1)
/// ```
@discardableResult
public func withScenarioReporter<Result>(
    _ reporter: any ScenarioReporter,
    operation: () throws -> Result
) rethrows -> Result {
    try ScenarioReporting.$current.withValue(reporter, operation: operation)
}

/// Async counterpart of `withScenarioReporter(_:operation:)`.
@discardableResult
public func withScenarioReporter<Result>(
    _ reporter: any ScenarioReporter,
    operation: () async throws -> Result
) async rethrows -> Result {
    try await ScenarioReporting.$current.withValue(reporter, operation: operation)
}

/// Builds a ``ScenarioFailure`` from a matcher mismatch, appends the step to the narrative, and
/// forwards it to the currently active ``ScenarioReporter``. Shared by the matcher-based `then`
/// (on `When`) and `and` (on `Then`) overloads so both stay perfectly consistent.
@discardableResult
func recordMatcherOutcome<Value>(
    description: String,
    actual: Value,
    matcher: Matcher<Value>,
    narrative: ScenarioNarrative,
    sourceLocation: SourceLocation
) -> ScenarioNarrative {
    var narrative = narrative
    narrative.appendThen(description)

    guard !matcher.matches(actual) else { return narrative }

    let failure = ScenarioFailure(
        message: "Expected \(description) to be \(matcher.description), but found \(actual).",
        narrative: narrative,
        sourceLocation: sourceLocation
    )
    ScenarioReporting.current.reportFailure(failure)
    return narrative
}
