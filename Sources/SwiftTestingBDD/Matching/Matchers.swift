/// Built-in ``Matcher`` factories covering the common cases. Everything here is a static
/// member on `Matcher`, so call sites read naturally as `.equal(3)`, `.beEmpty`, etc.
extension Matcher where Value: Equatable & Sendable {
    public static func equal(_ expected: Value) -> Matcher<Value> {
        Matcher(description: "equal to \(expected)") { $0 == expected }
    }

    public static func notEqual(_ expected: Value) -> Matcher<Value> {
        Matcher(description: "not equal to \(expected)") { $0 != expected }
    }
}

extension Matcher where Value: Comparable & Sendable {
    public static func beGreaterThan(_ bound: Value) -> Matcher<Value> {
        Matcher(description: "greater than \(bound)") { $0 > bound }
    }

    public static func beGreaterThanOrEqual(_ bound: Value) -> Matcher<Value> {
        Matcher(description: "greater than or equal to \(bound)") { $0 >= bound }
    }

    public static func beLessThan(_ bound: Value) -> Matcher<Value> {
        Matcher(description: "less than \(bound)") { $0 < bound }
    }

    public static func beLessThanOrEqual(_ bound: Value) -> Matcher<Value> {
        Matcher(description: "less than or equal to \(bound)") { $0 <= bound }
    }

    public static func be(in range: ClosedRange<Value>) -> Matcher<Value> {
        Matcher(description: "in the range \(range)") { range.contains($0) }
    }
}

extension Matcher where Value == Bool {
    public static var beTrue: Matcher<Bool> {
        Matcher(description: "true") { $0 }
    }

    public static var beFalse: Matcher<Bool> {
        Matcher(description: "false") { !$0 }
    }
}

extension Matcher {
    public static func beNil<Wrapped>() -> Matcher<Wrapped?> {
        Matcher<Wrapped?>(description: "nil") { $0 == nil }
    }

    public static func beSome<Wrapped>() -> Matcher<Wrapped?> {
        Matcher<Wrapped?>(description: "non-nil") { $0 != nil }
    }

    public static func beSome<Wrapped>(matching matcher: Matcher<Wrapped>) -> Matcher<Wrapped?> {
        Matcher<Wrapped?>(description: "some value \(matcher.description)") { value in
            guard let value else { return false }

            return matcher.matches(value)
        }
    }
}

extension Matcher where Value: Collection & Sendable {
    public static var beEmpty: Matcher<Value> {
        Matcher(description: "empty") { $0.isEmpty }
    }

    public static var beNotEmpty: Matcher<Value> {
        Matcher(description: "not empty") { !$0.isEmpty }
    }

    public static func haveCount(_ count: Int) -> Matcher<Value> {
        Matcher(description: "have count \(count)") { $0.count == count }
    }
}

extension Matcher where Value: Collection & Sendable, Value.Element: Equatable & Sendable {
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
