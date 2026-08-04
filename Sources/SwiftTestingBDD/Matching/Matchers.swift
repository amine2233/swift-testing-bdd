/// Built-in ``Matcher`` factories covering the common cases. Everything here is a static
/// member on `Matcher`, so call sites read naturally as `.equal(3)`, `.beEmpty`, etc.
extension Matcher where Value: Equatable & Sendable {
    /// Matches values equal to `expected`.
    /// - Parameter expected: The value the subject must equal.
    /// - Returns: A matcher describing itself as "equal to <expected>".
    public static func equal(_ expected: Value) -> Matcher<Value> {
        Matcher(description: "equal to \(expected)") { $0 == expected }
    }

    /// Matches values different from `expected`.
    /// - Parameter expected: The value the subject must not equal.
    /// - Returns: A matcher describing itself as "not equal to <expected>".
    public static func notEqual(_ expected: Value) -> Matcher<Value> {
        Matcher(description: "not equal to \(expected)") { $0 != expected }
    }
}

extension Matcher where Value: Comparable & Sendable {
    /// Matches values strictly greater than `bound`.
    /// - Parameter bound: The exclusive lower bound.
    /// - Returns: A matcher describing itself as "greater than <bound>".
    public static func beGreaterThan(_ bound: Value) -> Matcher<Value> {
        Matcher(description: "greater than \(bound)") { $0 > bound }
    }

    /// Matches values greater than or equal to `bound`.
    /// - Parameter bound: The inclusive lower bound.
    /// - Returns: A matcher describing itself as "greater than or equal to <bound>".
    public static func beGreaterThanOrEqual(_ bound: Value) -> Matcher<Value> {
        Matcher(description: "greater than or equal to \(bound)") { $0 >= bound }
    }

    /// Matches values strictly less than `bound`.
    /// - Parameter bound: The exclusive upper bound.
    /// - Returns: A matcher describing itself as "less than <bound>".
    public static func beLessThan(_ bound: Value) -> Matcher<Value> {
        Matcher(description: "less than \(bound)") { $0 < bound }
    }

    /// Matches values less than or equal to `bound`.
    /// - Parameter bound: The inclusive upper bound.
    /// - Returns: A matcher describing itself as "less than or equal to <bound>".
    public static func beLessThanOrEqual(_ bound: Value) -> Matcher<Value> {
        Matcher(description: "less than or equal to \(bound)") { $0 <= bound }
    }

    /// Matches values contained in `range`.
    /// - Parameter range: The closed range the subject must fall within.
    /// - Returns: A matcher describing itself as "in the range <range>".
    public static func be(in range: ClosedRange<Value>) -> Matcher<Value> {
        Matcher(description: "in the range \(range)") { range.contains($0) }
    }
}

extension Matcher where Value == Bool {
    /// Matches `true`.
    public static var beTrue: Matcher<Bool> {
        Matcher(description: "true") { $0 }
    }

    /// Matches `false`.
    public static var beFalse: Matcher<Bool> {
        Matcher(description: "false") { !$0 }
    }
}

extension Matcher {
    /// Matches an optional that holds no value.
    /// - Returns: A matcher describing itself as "nil".
    public static func beNil<Wrapped>() -> Matcher<Wrapped?> {
        Matcher<Wrapped?>(description: "nil") { $0 == nil }
    }

    /// Matches an optional that holds a value, whatever it is.
    /// - Returns: A matcher describing itself as "non-nil".
    public static func beSome<Wrapped>() -> Matcher<Wrapped?> {
        Matcher<Wrapped?>(description: "non-nil") { $0 != nil }
    }

    /// Matches an optional that holds a value satisfying `matcher`.
    /// - Parameter matcher: The matcher applied to the unwrapped value.
    /// - Returns: A matcher describing itself as "some value <matcher>".
    public static func beSome<Wrapped>(matching matcher: Matcher<Wrapped>) -> Matcher<Wrapped?> {
        Matcher<Wrapped?>(description: "some value \(matcher.description)") { value in
            guard let value else { return false }

            return matcher.matches(value)
        }
    }
}

extension Matcher where Value: Collection & Sendable {
    /// Matches an empty collection.
    public static var beEmpty: Matcher<Value> {
        Matcher(description: "empty") { $0.isEmpty }
    }

    /// Matches a collection with at least one element.
    public static var beNotEmpty: Matcher<Value> {
        Matcher(description: "not empty") { !$0.isEmpty }
    }

    /// Matches a collection with exactly `count` elements.
    /// - Parameter count: The expected number of elements.
    /// - Returns: A matcher describing itself as "have count <count>".
    public static func haveCount(_ count: Int) -> Matcher<Value> {
        Matcher(description: "have count \(count)") { $0.count == count }
    }
}

extension Matcher where Value: Collection & Sendable, Value.Element: Equatable & Sendable {
    /// Matches a collection containing `element`.
    /// - Parameter element: The element the collection must contain.
    /// - Returns: A matcher describing itself as "contain <element>".
    public static func contain(_ element: Value.Element) -> Matcher<Value> {
        Matcher(description: "contain \(element)") { $0.contains(element) }
    }
}

extension Matcher {
    /// Escape hatch for anything not covered above: describe the expectation yourself and
    /// supply the predicate directly.
    public static func satisfy(
        _ description: String,
        _ predicate: @escaping @Sendable (Value) -> Bool
    ) -> Matcher<Value> {
        Matcher(description: description, predicate: predicate)
    }
}
