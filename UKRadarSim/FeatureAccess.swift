import Foundation

/// Starter entitlement surface for future monetization.
///
/// Keep this intentionally small for now; it gives us one place to thread
/// StoreKit-backed access checks later without changing call sites.
enum SubscriptionTier: String, Codable {
    case free
    case premium
}

struct FeatureAccess {
    var subscriptionTier: SubscriptionTier = .free

    var hasPremiumEntitlements: Bool {
        subscriptionTier == .premium
    }

    // Future StoreKit hook:
    // - Resolve purchased auto-renewing subscriptions / transactions
    // - Map active products to `subscriptionTier`
    // - Publish updates into AppState so UI + content gating refreshes live
}

struct AirportConfig: Identifiable, Hashable {
    var id: String { icao }

    let icao: String
    let name: String
    /// Optional so legacy/default content can omit explicit gating.
    let isPremium: Bool?
}

struct WeatherPack: Identifiable, Hashable {
    let id: String
    let name: String
    /// Optional so standard packs can stay nil and inherit free behavior.
    let isPremium: Bool?
}
