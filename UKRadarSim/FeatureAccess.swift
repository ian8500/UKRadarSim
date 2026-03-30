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
}

/// Service boundary for access checks.
///
/// Future services (e.g. StoreKit) should conform to this protocol and can be
/// injected into `AppState` without changing the UI/access-gating call sites.
protocol EntitlementService: AnyObject {
    var hasPremiumEntitlements: Bool { get }
    var supportsPreviewToggle: Bool { get }

    /// Development convenience used by local previews.
    /// StoreKit-backed implementations can ignore this and keep the default no-op.
    func setPreviewPremiumEnabled(_ isEnabled: Bool)
}

extension EntitlementService {
    var supportsPreviewToggle: Bool { false }

    func setPreviewPremiumEnabled(_ isEnabled: Bool) {
        // Default no-op so production services can opt out.
    }
}

/// Local, development-oriented implementation that mimics future entitlement
/// behavior while retaining the existing premium preview toggle.
final class LocalPreviewEntitlementService: EntitlementService {
    private var featureAccess: FeatureAccess

    init(initialFeatureAccess: FeatureAccess = FeatureAccess()) {
        featureAccess = initialFeatureAccess
    }

    var hasPremiumEntitlements: Bool {
        featureAccess.hasPremiumEntitlements
    }

    var supportsPreviewToggle: Bool {
        true
    }

    func setPreviewPremiumEnabled(_ isEnabled: Bool) {
        featureAccess.subscriptionTier = isEnabled ? .premium : .free
    }
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
