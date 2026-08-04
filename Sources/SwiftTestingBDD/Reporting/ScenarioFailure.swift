import Testing

/// A single failure produced by the matcher-based side of the DSL (the `matches:` overloads
/// of `then`/`and`), carrying enough context to be reported richly by any ``ScenarioReporter``.
///
/// Closure-based assertions (`.then { context, result in #expect(...) }`) never produce a
/// `ScenarioFailure` — they go straight through Swift Testing's own `#expect`/`#require`
/// machinery, which already has the best possible source-location and value-diffing support.
/// `ScenarioFailure` exists specifically to give the *matcher* API (`Matcher<Value>`) the same
/// quality of reporting, including the full `Given`/`When`/`Then` narrative.
public struct ScenarioFailure: Sendable {
    /// A short, human-readable explanation of what was expected versus what was found.
    public let message: String

    /// The full scenario narrative recorded up to (and including) the failing step.
    public let narrative: ScenarioNarrative

    /// Where in the test source the failing step was written.
    public let sourceLocation: SourceLocation

    public init(message: String, narrative: ScenarioNarrative, sourceLocation: SourceLocation) {
        self.message = message
        self.narrative = narrative
        self.sourceLocation = sourceLocation
    }
}

extension ScenarioFailure: CustomStringConvertible {
    public var description: String {
        narrative.isEmpty ? message : "\(message)\n\nScenario so far:\n\(narrative)"
    }
}
