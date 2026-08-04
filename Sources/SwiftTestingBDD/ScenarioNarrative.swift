/// A running, human-readable transcript of the `Given` / `When` / `Then` steps that led up to
/// the current point in a scenario.
///
/// Every step in the DSL appends its description to a `ScenarioNarrative`, which is threaded
/// through the whole chain. When an assertion fails, the narrative is attached to the failure
/// so the report reads like the scenario itself, e.g.:
///
/// ```
/// Given a checkout fixture with an empty cart
/// And two espressos are added to the cart
/// When the cart is checked out
/// Then the receipt total reflects a 10% discount
/// ```
///
/// This is what makes `GivenWhenThen` failures self-describing across deep, multi-collaborator
/// object graphs — you don't have to reconstruct the setup from the test source to understand
/// what was being verified.
public struct ScenarioNarrative: Sendable, Equatable {
    public private(set) var givenSteps: [String]
    public private(set) var whenSteps: [String]
    public private(set) var thenSteps: [String]

    public init(
        givenSteps: [String] = [],
        whenSteps: [String] = [],
        thenSteps: [String] = []
    ) {
        self.givenSteps = givenSteps
        self.whenSteps = whenSteps
        self.thenSteps = thenSteps
    }

    /// `true` when no steps have been recorded yet.
    public var isEmpty: Bool {
        givenSteps.isEmpty && whenSteps.isEmpty && thenSteps.isEmpty
    }

    mutating func appendGiven(_ step: String) {
        givenSteps.append(step)
    }

    mutating func appendWhen(_ step: String) {
        whenSteps.append(step)
    }

    mutating func appendThen(_ step: String) {
        thenSteps.append(step)
    }
}

extension ScenarioNarrative: CustomStringConvertible {
    public var description: String {
        func format(_ keyword: String, _ steps: [String]) -> [String] {
            steps.enumerated().map { index, step in
                "\(index == 0 ? keyword : "And") \(step)"
            }
        }

        let lines = format("Given", givenSteps) + format("When", whenSteps) + format("Then", thenSteps)
        return lines.joined(separator: "\n")
    }
}
