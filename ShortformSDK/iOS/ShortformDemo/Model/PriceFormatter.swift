import Foundation

enum PriceFormatter {
    static func string(_ amount: Double, currency: String, locale: Locale = .current) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency
        f.locale = locale
        if ["KRW", "JPY"].contains(currency.uppercased()) {
            f.maximumFractionDigits = 0
            f.minimumFractionDigits = 0
        }
        return f.string(from: NSNumber(value: amount)) ?? "\(currency) \(amount)"
    }

    /// `11%` style discount label, or `nil` when there is no discount.
    static func discount(for product: Product) -> String? {
        guard product.hasDiscount else { return nil }
        let rate = product.discountRate ?? ((1 - product.salePrice / product.originalPrice) * 100)
        let rounded = Int(rate.rounded())
        return rounded > 0 ? "\(rounded)%" : nil
    }
}
