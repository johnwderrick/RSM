import Foundation

/// The Legends Balance economy, expressed in pounds at realistic football
/// scale.
///
/// Historical profiles stored Balance as small unit credits (a win paid 50,
/// the starter club held 500). The accepted rebalance multiplies every
/// Balance amount by `legacyUnitScale` (10,000) so the accepted relative
/// progression is preserved while amounts read like real football money:
/// a win pays £500,000, a facility upgrade costs £1,000,000+.
///
/// Pack tokens are a separate currency and never pass through this type.
enum LegendsBalance {
    /// Scale factor between the legacy unit-credit economy and the current
    /// pounds economy. Production amounts are expressed as
    /// `<legacy value> * legacyUnitScale` so the original progression
    /// stays visible at every site.
    static let legacyUnitScale = 10_000

    /// The economy version a save must carry to be considered already in
    /// the pounds scale. A profile decoding with a lower version migrates
    /// exactly once (see `LegendsProfile.init(from:)`); the marker is
    /// written back by the synthesised encode so repeated encode/decode
    /// cycles never multiply Balance twice.
    static let currentEconomyVersion = 1

    // MARK: - Formatting

    /// Full football-money text with grouped digits: £850,000 / £1,000,000.
    /// Used where transaction detail benefits from precision and for
    /// accessibility labels.
    static func full(_ amount: Int) -> String {
        let sign = amount < 0 ? "-" : ""
        return "\(sign)£\(grouped(abs(amount)))"
    }

    /// Compact football-money text for space-limited surfaces:
    /// £12.5M / £1.2M / £5M, with amounts under £1M kept fully grouped
    /// (£850,000) so they never round to a misleading figure.
    static func compact(_ amount: Int) -> String {
        let sign = amount < 0 ? "-" : ""
        let value = abs(amount)
        if value >= 1_000_000 {
            let millions = Double(value) / 1_000_000
            let text = String(format: "%.1f", millions)
            let trimmed = text.hasSuffix(".0") ? String(text.dropLast(2)) : text
            return "\(sign)£\(trimmed)M"
        }
        return full(amount)
    }

    /// Spoken form for accessibility labels — always the full monetary
    /// value so VoiceOver announces an understandable amount.
    static func spoken(_ amount: Int) -> String {
        full(amount)
    }

    private static func grouped(_ value: Int) -> String {
        var digits = String(value)
        var grouped = ""
        while digits.count > 3 {
            let split = digits.index(digits.endIndex, offsetBy: -3)
            grouped = "," + digits[split...] + grouped
            digits = String(digits[..<split])
        }
        return digits + grouped
    }
}
