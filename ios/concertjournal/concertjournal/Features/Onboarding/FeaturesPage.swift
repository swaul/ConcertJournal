//
//  FeaturesPage.swift
//  concertjournal
//
//  Created by Paul Kühnel on 10.02.26.
//

import SwiftUI

// MARK: - Features Page

enum FeatureInfo: CaseIterable {
    case calendar
    case spotify
    case photo
    case map

    var icon: String {
        switch self {
        case .calendar:
            "calendar"
        case .spotify:
            "music.note"
        case .photo:
            "photo.on.rectangle"
        case .map:
            "map"
        }
    }

    var title: String {
        switch self {
        case .calendar:
            "Konzerte dokumentieren"
        case .spotify:
            "Spotify Integration"
        case .photo:
            "Fotos & Erinnerungen"
        case .map:
            "Konzert-Karte"
        }
    }

    var description: String {
        switch self {
        case .calendar:
            "Halte alle deine Konzertbesuche mit Datum, Ort und Setlist fest"
        case .spotify:
            "Erstelle Playlists direkt aus deinen Setlists, oder importiere sie"
        case .photo:
            "Füge Fotos hinzu und erstelle dein persönliches Konzertarchiv"
        case .map:
            "Sieh alle besuchten Locations auf einer Karte"
        }
    }
}

struct FeaturesPage: View {

    @Bindable var navigationManager: NavigationManager

    let features = FeatureInfo.allCases
    @State private var visibleCount = 0

    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.3),
                    Color.accentColor.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Text("Was dich erwartet")
                    .font(.custom("PlayfairDisplay-Bold", size: 36))
                    .padding(.top, 60)

                VStack(spacing: 30) {
                    ForEach(features.enumerated(), id: \.element) { index, feature in
                        if index < visibleCount {
                            FeatureInfoRow(
                                icon: feature.icon,
                                title: feature.title,
                                description: feature.description
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()

                Button {
                    navigationManager.push(.photoPermission)
                } label: {
                    Text("Weiter gehts!")
                        .frame(maxWidth: .infinity)
                        .font(.cjTitle2)
                }
                .buttonStyle(.glass)
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .onAppear {
                for index in FeatureInfo.allCases.indices {
                    withAnimation(.easeInOut(duration: 0.75).delay(Double(index) * 0.5)) {
                        visibleCount = index + 1
                    }
                }
            }
        }
    }
}

struct FeatureInfoRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.accentColor)
                .frame(width: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.cjHeadline)

                Text(description)
                    .font(.cjFootnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }
}
