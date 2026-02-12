//
//  PayWall.swift
//  concertjournal
//
//  Created by Paul Kühnel on 12.02.26.
//

import SwiftUI
import StoreKit

struct PaywallView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var dependencies

    @State private var premiumManager = PremiumManager.shared
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    let highlightedFeature: PremiumFeature?

    init(highlightedFeature: PremiumFeature? = nil) {
        self.highlightedFeature = highlightedFeature
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Features
                    featuresSection

                    // Pricing
                    pricingSection

                    // Purchase Button
                    purchaseButton

                    // Benefits
                    benefitsSection

                    // Restore
                    restoreButton
                }
                .padding()
            }
            .background(backgroundColor)
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") {
                        dismiss()
                    }
                }
            }
            .alert("Erfolg!", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Du bist jetzt Premium-Mitglied! 🎉")
            }
            .alert("Fehler", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
        .onAppear {
            if selectedProduct == nil {
                selectedProduct = premiumManager.yearlyProduct ?? premiumManager.monthlyProduct
            }
        }
    }

    // MARK: - Header

    var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "crown.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
            }

            Text("Concert Journal")
                .font(.custom("PlayfairDisplay-Bold", size: 32))

            PremiumBadge()

            Text("Schalte alle Premium-Features frei")
                .font(.cjBody)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Features

    var featuresSection: some View {
        VStack(spacing: 12) {
            ForEach(premiumFeatures, id: \.self) { feature in
                FeatureRow(
                    feature: feature,
                    isHighlighted: feature == highlightedFeature
                )
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    var premiumFeatures: [PremiumFeature] {
        [
            .noAds,
            .unlimitedConcerts,
            .advancedStats,
            .ticketScanner,
            .customThemes,
            .cloudSync,
            .exportData,
            .aiRecommendations
        ]
    }

    // MARK: - Pricing

    var pricingSection: some View {
        VStack(spacing: 12) {
            if let yearly = premiumManager.yearlyProduct {
                PricingCard(
                    product: yearly,
                    isSelected: selectedProduct?.id == yearly.id,
                    badge: yearlyBadge,
                    savings: premiumManager.yearlyDiscount()
                ) {
                    selectedProduct = yearly
                }
            }

            if let monthly = premiumManager.monthlyProduct {
                PricingCard(
                    product: monthly,
                    isSelected: selectedProduct?.id == monthly.id,
                    badge: nil,
                    savings: nil
                ) {
                    selectedProduct = monthly
                }
            }

            if let lifetime = premiumManager.lifetimeProduct {
                PricingCard(
                    product: lifetime,
                    isSelected: selectedProduct?.id == lifetime.id,
                    badge: "EINMALIG",
                    savings: nil
                ) {
                    selectedProduct = lifetime
                }
            }
        }
    }

    var yearlyBadge: String {
        if let discount = premiumManager.yearlyDiscount() {
            return "SPARE \(discount)%"
        }
        return "BELIEBT"
    }

    // MARK: - Purchase Button

    var purchaseButton: some View {
        Button {
            Task {
                await purchase()
            }
        } label: {
            Group {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Jetzt Premium werden")
                        .font(.cjHeadline)
                }
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
        .disabled(isPurchasing || selectedProduct == nil)
        .opacity((isPurchasing || selectedProduct == nil) ? 0.6 : 1.0)
    }

    // MARK: - Benefits

    var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Deine Vorteile:")
                .font(.cjHeadline)

            BenefitRow(icon: "checkmark.circle.fill", text: "Keine Werbung mehr")
            BenefitRow(icon: "checkmark.circle.fill", text: "Unbegrenzte Konzerte")
            BenefitRow(icon: "checkmark.circle.fill", text: "Cloud-Synchronisation")
            BenefitRow(icon: "checkmark.circle.fill", text: "Exklusive Features")
            BenefitRow(icon: "checkmark.circle.fill", text: "Jederzeit kündbar")
        }
        .padding()
        .background(dependencies.colorThemeManager.appTint.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Restore Button

    var restoreButton: some View {
        Button {
            Task {
                await restore()
            }
        } label: {
            if isRestoring {
                ProgressView()
            } else {
                Text("Käufe wiederherstellen")
                    .font(.cjFootnote)
                    .foregroundColor(.secondary)
            }
        }
        .disabled(isRestoring)
    }

    // MARK: - Actions

    private func purchase() async {
        guard let product = selectedProduct else { return }

        isPurchasing = true

        do {
            try await premiumManager.purchase(product)
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isPurchasing = false
    }

    private func restore() async {
        isRestoring = true

        do {
            try await premiumManager.restorePurchases()
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isRestoring = false
    }

    // MARK: - Helpers

    var backgroundColor: some View {
        LinearGradient(
            colors: [
                dependencies.colorThemeManager.appTint.opacity(0.05),
                dependencies.colorThemeManager.appTint.opacity(0.1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - Feature Row

struct FeatureRow: View {

    @Environment(\.dependencies) private var dependencies

    let feature: PremiumFeature
    let isHighlighted: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: feature.icon)
                .font(.system(size: 20))
                .foregroundColor(isHighlighted ? .orange : dependencies.colorThemeManager.appTint)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.displayName)
                    .font(isHighlighted ? .cjHeadline : .cjBody)

                if isHighlighted {
                    Text(feature.description)
                        .font(.cjCaption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
        .padding(isHighlighted ? 12 : 8)
        .background(
            isHighlighted
            ? Color.orange.opacity(0.1)
            : Color.clear
        )
        .cornerRadius(8)
    }
}

// MARK: - Pricing Card

struct PricingCard: View {

    @Environment(\.dependencies) private var dependencies

    let product: Product
    let isSelected: Bool
    let badge: String?
    let savings: Int?
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .cornerRadius(12)
                }

                Text(product.displayName)
                    .font(.cjHeadline)

                Text(product.displayPrice)
                    .font(.system(size: 32, weight: .bold))

                Text(pricePerMonth)
                    .font(.cjCaption)
                    .foregroundColor(.secondary)

                if let savings = savings {
                    Text("Du sparst \(savings)%")
                        .font(.cjCaption)
                        .foregroundColor(.green)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? dependencies.colorThemeManager.appTint : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    var pricePerMonth: String {
        if product.id.contains("yearly") {
            let monthlyPrice = product.price / 12
            return String(format: "%.2f€ pro Monat", monthlyPrice as NSNumber as! CVarArg)
        } else if product.id.contains("lifetime") {
            return "Einmalige Zahlung"
        } else {
            return "Pro Monat"
        }
    }
}

// MARK: - Benefit Row

struct BenefitRow: View {

    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
            Text(text)
                .font(.cjBody)
        }
    }
}

// MARK: - Preview

#Preview {
    PaywallView()
}

#Preview("With Feature") {
    PaywallView(highlightedFeature: .ticketScanner)
}
