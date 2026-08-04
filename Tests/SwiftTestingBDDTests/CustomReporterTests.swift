import Foundation
import SwiftTestingBDD
import Testing

/// A reporter that records failures instead of forwarding them to `Issue.record`, so we can
/// assert on the DSL's own failure-reporting behavior. `@unchecked Sendable` is safe here
/// because each test creates its own instance and never shares it across concurrent tasks.
final class RecordingReporter: ScenarioReporter, @unchecked Sendable {
    private(set) var failures: [ScenarioFailure] = []

    func reportFailure(_ failure: ScenarioFailure) {
        failures.append(failure)
    }
}

@Suite("Custom ScenarioReporter integration")
struct CustomReporterTests {
    @Test("A custom reporter captures matcher failures with the full scenario narrative")
    func customReporterCapturesFailureNarrative() {
        let reporter = RecordingReporter()

        withScenarioReporter(reporter) {
            given("a checkout fixture with an empty cart") {
                CheckoutFixture.makeEmpty()
            }
            .and("a croissant is added to the cart") { fixture in
                fixture.cart.add(croissant)
            }
            .when("the subtotal is computed") { fixture in
                fixture.pricing.subtotal(for: fixture.cart)
            }
            .then(
                "the subtotal is (intentionally) checked against the wrong amount",
                \.self,
                matches: .equal(Decimal(string: "99.00")!)
            )
        }

        #expect(reporter.failures.count == 1)

        let failure = reporter.failures[0]
        #expect(failure.message.contains("99"))
        #expect(failure.narrative.givenSteps == [
            "a checkout fixture with an empty cart",
            "a croissant is added to the cart"
        ])
        #expect(failure.narrative.whenSteps == ["the subtotal is computed"])
        #expect(failure.narrative.thenSteps == [
            "the subtotal is (intentionally) checked against the wrong amount"
        ])
    }

    @Test("A passing matcher-based scenario reports no failures")
    func matchingScenarioReportsNothing() {
        let reporter = RecordingReporter()

        withScenarioReporter(reporter) {
            given("a checkout fixture with an empty cart") {
                CheckoutFixture.makeEmpty()
            }
            .and("an espresso is added to the cart") { fixture in
                fixture.cart.add(espresso)
            }
            .when("the subtotal is computed") { fixture in
                fixture.pricing.subtotal(for: fixture.cart)
            }
            .then(
                "the subtotal equals the espresso's price",
                \.self,
                matches: .equal(Decimal(string: "3.50")!)
            )
        }

        #expect(reporter.failures.isEmpty)
    }

    @Test("Matcher combinators compose with &&, ||, and !")
    func matcherCombinators() {
        let isPositive = Matcher<Int>.beGreaterThan(0)
        let isEven = Matcher<Int>.satisfy("even") { $0 % 2 == 0 }

        #expect((isPositive && isEven).matches(4))
        #expect(!(isPositive && isEven).matches(-4))
        #expect((isPositive || isEven).matches(-4))
        #expect((!isPositive).matches(-1))
    }
}
