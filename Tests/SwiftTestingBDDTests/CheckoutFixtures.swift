import Foundation

// A small point-of-sale-style domain used across the test suite to exercise the DSL against a
// realistic service layer with multiple collaborators (a repository-like ledger and a pricing
// engine), rather than a single trivial type.

struct Product: Sendable, Equatable {
    let sku: String
    let name: String
    let unitPrice: Decimal
}

struct CartLine: Sendable, Equatable {
    let product: Product
    let quantity: Int
}

struct Cart: Sendable {
    var lines: [CartLine] = []
    var discountCode: String?

    mutating func add(_ product: Product, quantity: Int = 1) {
        lines.append(CartLine(product: product, quantity: quantity))
    }
}

enum CheckoutError: Error, Equatable {
    case emptyCart
    case reservationFailed(sku: String)
}

/// A tiny in-memory stand-in for an inventory service. `@unchecked Sendable` is safe here
/// because every test constructs its own instance and never shares it across concurrent tasks —
/// a common pattern for test doubles.
final class InventoryLedger: @unchecked Sendable {
    private(set) var reservations: [String: Int] = [:]
    var skuThatFailsToReserve: String?

    func reserve(sku: String, quantity: Int) throws {
        if sku == skuThatFailsToReserve {
            throw CheckoutError.reservationFailed(sku: sku)
        }
        reservations[sku, default: 0] += quantity
    }
}

struct PricingEngine: Sendable {
    func subtotal(for cart: Cart) -> Decimal {
        cart.lines.reduce(Decimal(0)) { $0 + $1.product.unitPrice * Decimal($1.quantity) }
    }

    func total(for cart: Cart) -> Decimal {
        let subtotal = subtotal(for: cart)
        guard cart.discountCode == "WELCOME10" else { return subtotal }

        // Integer arithmetic keeps this exact — avoid constructing Decimal from binary-float
        // literals like `0.9` for money math.
        let discount = (subtotal * 10) / 100
        return subtotal - discount
    }
}

struct Receipt: Sendable, Equatable {
    let total: Decimal
    let reservedSKUs: [String]
}

/// The service layer under test. Depends on two collaborators, mirroring a typical
/// point-of-sale checkout flow.
struct CheckoutService: Sendable {
    let ledger: InventoryLedger
    let pricing: PricingEngine

    func checkout(_ cart: Cart) throws -> Receipt {
        guard !cart.lines.isEmpty else { throw CheckoutError.emptyCart }

        for line in cart.lines {
            try ledger.reserve(sku: line.product.sku, quantity: line.quantity)
        }
        return Receipt(total: pricing.total(for: cart), reservedSKUs: cart.lines.map(\.product.sku))
    }
}

/// The `Given` context: the whole object graph the scenario needs — cart plus the service and
/// its collaborators — bundled into one `Sendable` value.
struct CheckoutFixture: Sendable {
    var cart: Cart
    let ledger: InventoryLedger
    let pricing: PricingEngine

    var service: CheckoutService {
        CheckoutService(ledger: ledger, pricing: pricing)
    }

    static func makeEmpty() -> CheckoutFixture {
        CheckoutFixture(cart: Cart(), ledger: InventoryLedger(), pricing: PricingEngine())
    }
}

let espresso = Product(sku: "ESP-001", name: "Espresso", unitPrice: Decimal(string: "3.50")!)
let croissant = Product(sku: "CRO-002", name: "Croissant", unitPrice: Decimal(string: "2.75")!)
