import Foundation
import SwiftTestingBDD
import Testing

@Suite("Checkout scenarios (Given/When/Then)")
struct CheckoutScenarioTests {
    @Test("Checking out a cart with a valid discount code reserves inventory and applies 10% off")
    func checkoutAppliesDiscountAndReservesInventory() throws {
        try given("a checkout fixture with an empty cart") {
            CheckoutFixture.makeEmpty()
        }
        .and("two espressos are added to the cart") { fixture in
            fixture.cart.add(espresso, quantity: 2)
        }
        .and("a croissant is added to the cart") { fixture in
            fixture.cart.add(croissant)
        }
        .and("a WELCOME10 discount code is applied") { fixture in
            fixture.cart.discountCode = "WELCOME10"
        }
        .when("the cart is checked out") { fixture in
            try fixture.service.checkout(fixture.cart)
        }
        .then("the receipt total reflects a 10% discount") { _, receipt in
            #expect(receipt.total == Decimal(string: "8.775")!)
        }
        .and("the espresso SKU was reserved", \.reservedSKUs, matches: .contain("ESP-001"))
        .and("the croissant SKU was reserved", \.reservedSKUs, matches: .contain("CRO-002"))
        .and(
            "the ledger recorded exactly two distinct SKU reservations",
            context: \.ledger.reservations.count,
            matches: .equal(2)
        )
    }

    @Test("Checking out an empty cart is rejected before any inventory is touched")
    func checkoutRejectsEmptyCart() throws {
        try given("a checkout fixture with an empty cart") {
            CheckoutFixture.makeEmpty()
        }
        .when("checkout is attempted") { fixture in
            try #require(throws: CheckoutError.self) {
                try fixture.service.checkout(fixture.cart)
            }
        }
        .then("the emptyCart error is thrown") { _, error in
            #expect(error == CheckoutError.emptyCart)
        }
        .and("no reservations were recorded", context: \.ledger.reservations, matches: .beEmpty)
    }

    @Test("A downstream reservation failure propagates and stops the checkout")
    func checkoutFailsWhenReservationFails() throws {
        try given("a checkout fixture where ESP-001 cannot be reserved") { () -> CheckoutFixture in
            let fixture = CheckoutFixture.makeEmpty()
            fixture.ledger.skuThatFailsToReserve = "ESP-001"
            return fixture
        }
        .and("an espresso is added to the cart") { fixture in
            fixture.cart.add(espresso)
        }
        .when("checkout is attempted") { fixture in
            try #require(throws: CheckoutError.self) {
                try fixture.service.checkout(fixture.cart)
            }
        }
        .then("the reservationFailed error names the right SKU") { _, error in
            #expect(error == CheckoutError.reservationFailed(sku: "ESP-001"))
        }
    }

    @Test(
        "Parameterized: subtotal scales linearly with quantity",
        arguments: [1, 2, 5, 10]
    )
    func subtotalScalesWithQuantity(quantity: Int) {
        given("a checkout fixture with an empty cart") {
            CheckoutFixture.makeEmpty()
        }
        .and("\(quantity) espresso(s) are added to the cart") { fixture in
            fixture.cart.add(espresso, quantity: quantity)
        }
        .when("the subtotal is computed") { fixture in
            fixture.pricing.subtotal(for: fixture.cart)
        }
        .then("the subtotal equals unit price times quantity") { _, subtotal in
            #expect(subtotal == espresso.unitPrice * Decimal(quantity))
        }
    }
}

// MARK: - Compile-time safety (illustrative — intentionally not part of the build)

//
// The Given → When → Then order is enforced by the type checker, not by convention. Each of
// the lines below fails to *compile*, not just to run, because the type on the left has no
// such member:
//
//   let g = given("a cart") { Cart() }
//   g.then { _, _ in }                       // ❌ value of type 'Given<Cart>' has no member 'then'
//
//   let w = g.when("it is emptied") { $0.lines.removeAll() }
//   w.and("more setup") { $0.discountCode = "X" }   // ❌ no overload of 'and' matches (Void, Cart) -> Void
//   w.given(...)                                    // ❌ value of type 'When<Cart, Void>' has no member
//   'given'
//
//   let t = w.then("it has no lines") { context, _ in #expect(context.lines.isEmpty) }
//   t.when { _ in }                          // ❌ value of type 'Then<Cart, Void>' has no member 'when'
