/// A named predicate over `Value`, used by the matcher-based `then`/`and` overloads to produce
/// self-describing failure messages (e.g. "Expected the receipt total to be equal to 8.775, but
/// found 9.75.") without needing a macro or the `#expect` machinery.
///
/// `Matcher` is intentionally tiny — it's a description plus a predicate — so it composes with
/// `&&`, `||`, and `!`, and is easy to extend with your own domain-specific vocabulary (see
/// `Matchers.swift` for the built-ins).
public struct Matcher<Value>: Sendable {
    public let description: String
    private let predicate: @Sendable (Value) -> Bool

    public init(description: String, predicate: @escaping @Sendable (Value) -> Bool) {
        self.description = description
        self.predicate = predicate
    }

    public func matches(_ value: Value) -> Bool {
        predicate(value)
    }
}

extension Matcher {
    /// Adapts a matcher over `Value` into one over `NewValue`, by transforming the incoming
    /// value before applying the underlying predicate. Handy for reusing a matcher written for
    /// one type against a related type extracted from your context or result, e.g. adapting an
    /// `Int` count matcher into one that reads `someCollection.count` for you.
    public func pullback<NewValue>(_ transform: @escaping @Sendable (NewValue) -> Value)
        -> Matcher<NewValue> {
        Matcher<NewValue>(description: description) { predicate(transform($0)) }
    }
}

// MARK: - Logical composition

extension Matcher {
    /// Negates a matcher: the result matches exactly when `matcher` does not.
    /// - Parameter matcher: The matcher to negate.
    /// - Returns: A matcher describing itself as "not <description>".
    public static prefix func ! (matcher: Matcher<Value>) -> Matcher<Value> {
        Matcher(description: "not \(matcher.description)") { !matcher.matches($0) }
    }

    /// Combines two matchers so the result matches only when both do.
    /// - Parameters:
    ///   - lhs: The first matcher.
    ///   - rhs: The second matcher.
    /// - Returns: A matcher describing itself as "<lhs> and <rhs>".
    public static func && (lhs: Matcher<Value>, rhs: Matcher<Value>) -> Matcher<Value> {
        Matcher(description: "\(lhs.description) and \(rhs.description)") {
            lhs.matches($0) && rhs.matches($0)
        }
    }

    /// Combines two matchers so the result matches when either does.
    /// - Parameters:
    ///   - lhs: The first matcher.
    ///   - rhs: The second matcher.
    /// - Returns: A matcher describing itself as "<lhs> or <rhs>".
    public static func || (lhs: Matcher<Value>, rhs: Matcher<Value>) -> Matcher<Value> {
        Matcher(description: "\(lhs.description) or \(rhs.description)") {
            lhs.matches($0) || rhs.matches($0)
        }
    }
}
