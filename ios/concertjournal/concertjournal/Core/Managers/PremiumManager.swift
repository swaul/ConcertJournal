//
//  PremiumManager.swift
//  concertjournal
//
//  Created by Paul Kühnel on 12.02.26.
//

import SwiftUI
import StoreKit

// MARK: - Premium Features

enum PremiumFeature: String, CaseIterable {
    case unlimitedConcerts = "unlimited_concerts"
    case advancedStats = "advanced_stats"
    case cloudSync = "cloud_sync"
    case customThemes = "custom_themes"
    case exportData = "export_data"
    case prioritySupport = "priority_support"
    case aiRecommendations = "ai_recommendations"
    case concertReminders = "concert_reminders"
    case shareToSocial = "share_to_social"
    case advancedFilters = "advanced_filters"
    case multiplePhotos = "multiple_photos"
    case concertNotes = "concert_notes"
    case setlistImport = "setlist_import"
    case ticketScanner = "ticket_scanner"
    case noAds = "no_ads"

    var displayName: String {
        switch self {
        case .unlimitedConcerts: return "Unbegrenzte Konzerte"
        case .advancedStats: return "Erweiterte Statistiken"
        case .cloudSync: return "Cloud Synchronisation"
        case .customThemes: return "Benutzerdefinierte Themes"
        case .exportData: return "Daten Export (PDF/CSV)"
        case .prioritySupport: return "Prioritäts-Support"
        case .aiRecommendations: return "KI Konzert-Empfehlungen"
        case .concertReminders: return "Konzert-Erinnerungen"
        case .shareToSocial: return "Social Media Sharing"
        case .advancedFilters: return "Erweiterte Filter"
        case .multiplePhotos: return "Mehrere Fotos pro Konzert"
        case .concertNotes: return "Detaillierte Notizen"
        case .setlistImport: return "Setlist Import"
        case .ticketScanner: return "Ticket Scanner"
        case .noAds: return "Werbefrei"
        }
    }

    var icon: String {
        switch self {
        case .unlimitedConcerts: return "infinity"
        case .advancedStats: return "chart.bar.fill"
        case .cloudSync: return "icloud.fill"
        case .customThemes: return "paintpalette.fill"
        case .exportData: return "square.and.arrow.up.fill"
        case .prioritySupport: return "headphones"
        case .aiRecommendations: return "sparkles"
        case .concertReminders: return "bell.badge.fill"
        case .shareToSocial: return "square.and.arrow.up.circle.fill"
        case .advancedFilters: return "line.3.horizontal.decrease.circle.fill"
        case .multiplePhotos: return "photo.stack.fill"
        case .concertNotes: return "note.text"
        case .setlistImport: return "music.note.list"
        case .ticketScanner: return "qrcode.viewfinder"
        case .noAds: return "eye.slash.fill"
        }
    }

    var description: String {
        switch self {
        case .unlimitedConcerts:
            return "Speichere unbegrenzt viele Konzerte in deinem Journal"
        case .advancedStats:
            return "Detaillierte Statistiken zu deinen Konzertbesuchen, Künstlern und Locations"
        case .cloudSync:
            return "Synchronisiere deine Daten automatisch über alle Geräte"
        case .customThemes:
            return "Wähle aus verschiedenen Farbthemes oder erstelle dein eigenes"
        case .exportData:
            return "Exportiere deine Konzerte als PDF oder CSV für Backup"
        case .prioritySupport:
            return "Erhalte bevorzugten Support bei Fragen oder Problemen"
        case .aiRecommendations:
            return "KI-basierte Konzertempfehlungen basierend auf deinem Geschmack"
        case .concertReminders:
            return "Automatische Erinnerungen für bevorstehende Konzerte"
        case .shareToSocial:
            return "Teile deine Konzertbesuche schön formatiert auf Social Media"
        case .advancedFilters:
            return "Filtere und sortiere deine Konzerte nach vielen Kriterien"
        case .multiplePhotos:
            return "Füge bis zu 20 Fotos pro Konzert hinzu"
        case .concertNotes:
            return "Schreibe ausführliche Notizen zu jedem Konzert"
        case .setlistImport:
            return "Importiere Setlists von setlist.fm"
        case .ticketScanner:
            return "Scanne Tickets automatisch mit KI"
        case .noAds:
            return "Genieße die App ohne Werbeunterbrechungen"
        }
    }

    var isAvailableInFree: Bool {
        switch self {
        case .unlimitedConcerts: return false  // Free: Max 10 Konzerte
        case .advancedStats: return false
        case .cloudSync: return false
        case .customThemes: return false       // Free: Nur Standard Theme
        case .exportData: return false
        case .prioritySupport: return false
        case .aiRecommendations: return false
        case .concertReminders: return true    // Free hat basic reminders
        case .shareToSocial: return false
        case .advancedFilters: return false    // Free: Nur basic filter
        case .multiplePhotos: return false     // Free: Max 3 Fotos
        case .concertNotes: return false       // Free: Max 100 Zeichen
        case .setlistImport: return false
        case .ticketScanner: return false
        case .noAds: return false
        }
    }
}

// MARK: - Premium Manager

@Observable
class PremiumManager {

    static let shared = PremiumManager()

    // MARK: - Properties

    var isPremium: Bool = false
    var subscriptionEndDate: Date?
    var availableProducts: [Product] = []
    var isLoadingProducts = false

    // Free tier limits
    let freeConcertLimit = 10
    let freePhotoLimit = 3
    let freeNotesLimit = 100

    // Product IDs (Ersetze mit deinen aus App Store Connect)
    private let monthlyProductID = "com.yourcompany.concertjournal.premium.monthly"
    private let yearlyProductID = "com.yourcompany.concertjournal.premium.yearly"
    private let lifetimeProductID = "com.yourcompany.concertjournal.premium.lifetime"

    // MARK: - Initialization

    private init() {
        loadPremiumStatus()
        Task {
            await loadProducts()
            await checkSubscriptionStatus()
        }
    }

    // MARK: - Premium Check

    func hasAccess(to feature: PremiumFeature) -> Bool {
        if isPremium {
            return true
        }
        return feature.isAvailableInFree
    }

    func checkLimit(concerts: Int) -> Bool {
        if isPremium {
            return true
        }
        return concerts < freeConcertLimit
    }

    private func loadPremiumStatus() {
        isPremium = UserDefaults.standard.bool(forKey: "isPremium")
        if let endDateTimestamp = UserDefaults.standard.object(forKey: "subscriptionEndDate") as? TimeInterval {
            subscriptionEndDate = Date(timeIntervalSince1970: endDateTimestamp)
        }
    }

    private func savePremiumStatus() {
        UserDefaults.standard.set(isPremium, forKey: "isPremium")
        if let endDate = subscriptionEndDate {
            UserDefaults.standard.set(endDate.timeIntervalSince1970, forKey: "subscriptionEndDate")
        }

        // Update AdMob
        AdMobManager.shared.setPremium(isPremium)
    }

    // MARK: - StoreKit

    func loadProducts() async {
        isLoadingProducts = true

        do {
            let products = try await Product.products(for: [
                monthlyProductID,
                yearlyProductID,
                lifetimeProductID
            ])

            await MainActor.run {
                self.availableProducts = products.sorted { $0.price < $1.price }
                self.isLoadingProducts = false
            }

            logInfo("Loaded \(products.count) products", category: .premium)

        } catch {
            logError("Failed to load products", error: error, category: .premium)
            await MainActor.run {
                self.isLoadingProducts = false
            }
        }
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            // Verify the transaction
            let transaction = try checkVerified(verification)

            // Unlock premium
            await MainActor.run {
                self.isPremium = true
                self.savePremiumStatus()
            }

            // Finish transaction
            await transaction.finish()

            logSuccess("Purchase successful: \(product.id)", category: .premium)

        case .userCancelled:
            logInfo("Purchase cancelled by user", category: .premium)

        case .pending:
            logInfo("Purchase pending", category: .premium)

        @unknown default:
            break
        }
    }

    func restorePurchases() async throws {
        var restoredPurchases = 0

        for await result in Transaction.currentEntitlements {
            let transaction = try checkVerified(result)

            if transaction.productID == monthlyProductID ||
                transaction.productID == yearlyProductID ||
                transaction.productID == lifetimeProductID {

                await MainActor.run {
                    self.isPremium = true
                    self.savePremiumStatus()
                }

                restoredPurchases += 1
            }
        }

        if restoredPurchases > 0 {
            logSuccess("Restored \(restoredPurchases) purchases", category: .premium)
        } else {
            throw PremiumError.noPurchasesToRestore
        }
    }

    private func checkSubscriptionStatus() async {
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                if transaction.productID == monthlyProductID ||
                    transaction.productID == yearlyProductID ||
                    transaction.productID == lifetimeProductID {

                    await MainActor.run {
                        self.isPremium = true

                        // Set expiry date for subscriptions
                        if let expirationDate = transaction.expirationDate {
                            self.subscriptionEndDate = expirationDate
                        }

                        self.savePremiumStatus()
                    }
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PremiumError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Helper Methods

    var monthlyProduct: Product? {
        availableProducts.first { $0.id == monthlyProductID }
    }

    var yearlyProduct: Product? {
        availableProducts.first { $0.id == yearlyProductID }
    }

    var lifetimeProduct: Product? {
        availableProducts.first { $0.id == lifetimeProductID }
    }

    func yearlyDiscount() -> Int? {
        guard let monthly = monthlyProduct,
              let yearly = yearlyProduct else { return nil }

        let monthlyYearlyCost = monthly.price * 12
        let yearlyCost = yearly.price
        let savings = monthlyYearlyCost - yearlyCost
        let percentage = (savings / monthlyYearlyCost) * 100

        return Int(truncating: percentage as NSNumber)
    }
}

// MARK: - Errors

enum PremiumError: LocalizedError {
    case failedVerification
    case noPurchasesToRestore

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Die Transaktion konnte nicht verifiziert werden"
        case .noPurchasesToRestore:
            return "Keine Käufe zum Wiederherstellen gefunden"
        }
    }
}

// MARK: - Premium Badge View

struct PremiumBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "crown.fill")
                .font(.system(size: 12))
            Text("PRO")
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            LinearGradient(
                colors: [.orange, .yellow],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(8)
    }
}

// MARK: - Feature Lock View

struct FeatureLockView: View {

    let feature: PremiumFeature
    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text(feature.displayName)
                .font(.cjTitle2)

            Text(feature.description)
                .font(.cjBody)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                showPaywall = true
            } label: {
                HStack {
                    Image(systemName: "crown.fill")
                    Text("Premium freischalten")
                        .font(.cjHeadline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.orange, .yellow],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(highlightedFeature: feature)
        }
    }
}

// MARK: - View Extension

extension View {

    /// Locks feature behind premium
    func requiresPremium(_ feature: PremiumFeature) -> some View {
        Group {
            if PremiumManager.shared.hasAccess(to: feature) {
                self
            } else {
                FeatureLockView(feature: feature)
            }
        }
    }
}
