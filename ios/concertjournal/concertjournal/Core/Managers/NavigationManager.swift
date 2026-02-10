//
//  NavigationManager.swift
//  concertjournal
//
//  Created by Paul Kühnel on 31.01.26.
//

import SwiftUI
import Observation

enum NavigationRoute: Hashable {
    // Main Tabs
    case concerts
    case map
    case search

    // Concert Related
    case concertDetail(FullConcertVisit)
    case createConcert
    case createConcertFromImport(ImportedConcert)
    case editConcert(FullConcertVisit)

    // Artist Related
    case selectArtist
    case artistDetail(Artist)

    // Venue Related
    case selectVenue
    case venueDetail(Venue)

    // Setlist
    case createSetlist(concertId: String)
    case orderSetlist(CreateSetlistViewModel)

    case playlist
    
    // Profile
    case profile
    case settings
    case colorPicker
    case faq
    case about
    case privacy
    case impressum

    // Onboarding
    case trackingPermission
    case photoPermission
    case featurePage
    case completion
}

@Observable
class NavigationManager {

    // MARK: - State

    /// Navigation Stack Path
    var path: NavigationPath = NavigationPath()

    /// Aktuell präsentiertes Sheet
    var presentedSheet: NavigationRoute?

    /// Aktuell präsentiertes Full Screen Cover
    var presentedFullScreenCover: NavigationRoute?

    /// Selected Tab (für TabView)
    var selectedTab: NavigationRoute = .concerts

    // MARK: - Navigation Actions

    /// Push eine neue View auf den Stack
    func push(_ route: NavigationRoute) {
        path.append(route)
    }

    /// Pop zurück zur vorherigen View
    func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }

    /// Pop zurück zur Root View
    func popToRoot() {
        path = NavigationPath()
    }

    /// Pop zu einer bestimmten Route
    func popTo(_ route: NavigationRoute) {
        // Implementierung hängt von deinen Anforderungen ab
        // Momentan wird einfach zur Root gepoppt
        popToRoot()
    }

    /// Zeige Sheet
    func presentSheet(_ route: NavigationRoute) {
        presentedSheet = route
    }

    /// Zeige Full Screen Cover
    func presentFullScreenCover(_ route: NavigationRoute) {
        presentedFullScreenCover = route
    }

    /// Dismiss aktuelles Sheet/Cover
    func dismiss() {
        presentedSheet = nil
        presentedFullScreenCover = nil
    }

    /// Wechsel Tab
    func switchTab(to tab: NavigationRoute) {
        selectedTab = tab
        popToRoot() // Reset navigation stack when switching tabs
    }
}

private struct NavigationManagerKey: EnvironmentKey {
    static let defaultValue = NavigationManager()
}

extension EnvironmentValues {
    var navigationManager: NavigationManager {
        get { self[NavigationManagerKey.self] }
        set { self[NavigationManagerKey.self] = newValue }
    }
}

extension View {
    func withNavigationManager(_ manager: NavigationManager) -> some View {
        self.environment(\.navigationManager, manager)
    }
}

extension NavigationManager {

    /// Handle Deep Link
    func handle(url: URL) {
        // Parse URL und navigiere
        // z.B. myapp://concert/123

        if url.pathComponents.contains("concert"),
           let concertId = url.pathComponents.last {

            // Load concert und navigiere
            Task {
                // let concert = try await loadConcert(id: concertId)
                // push(.concertDetail(concert))
            }
        }
    }
}

// Placeholder Views
//struct MapView: View { var body: some View { Text("Map") } }
//struct ProfileView: View { var body: some View { Text("Profile") } }
//struct ConcertDetailView: View { let concert: FullConcertVisit; var body: some View { Text("Detail") } }
//struct EditConcertView: View { let concert: FullConcertVisit; var body: some View { Text("Edit") } }
//struct CreateConcertView: View { var body: some View { Text("Create") } }
//struct SelectArtistView: View { var body: some View { Text("Select Artist") } }
//struct SelectVenueView: View { var body: some View { Text("Select Venue") } }
//struct ArtistDetailView: View { let artist: Artist; var body: some View { Text("Artist") } }
//struct VenueDetailView: View { let venue: Venue; var body: some View { Text("Venue") } }
//struct CreateSetlistView: View { let concertId: String; var body: some View { Text("Setlist") } }
//struct ColorSetView: View { var body: some View { Text("Colors") } }
//struct FAQView: View { var body: some View { Text("FAQ") } }
//struct AboutView: View { var body: some View { Text("About") } }
//struct PrivacyView: View { var body: some View { Text("Privacy") } }
//struct ImpressumView: View { var body: some View { Text("Impressum") } }
//struct SettingsView: View { var body: some View { Text("Settings") } }

// Make NavigationRoute Identifiable for sheet presentation
extension NavigationRoute: Identifiable {
    var id: String {
        switch self {
        case .concerts: return "concerts"
        case .map: return "map"
        case .profile: return "profile"
        case .concertDetail(let concert): return "concert-\(concert.id)"
        case .createConcert: return "create-concert"
        case .createConcertFromImport(let imported): return "create-concert-from-\(imported)"
        case .editConcert(let concert): return "edit-\(concert.id)"
        case .selectArtist: return "select-artist"
        case .artistDetail(let artist): return "artist-\(artist.id)"
        case .selectVenue: return "select-venue"
        case .venueDetail(let venue): return "venue-\(venue.id)"
        case .createSetlist(let id): return "setlist-\(id)"
        case .orderSetlist(let viewModel): return "orderSetlist-\(viewModel)"
        case .settings: return "settings"
        case .colorPicker: return "color-picker"
        case .faq: return "faq"
        case .about: return "about"
        case .privacy: return "privacy"
        case .impressum: return "impressum"
        case .playlist: return ""
        case .trackingPermission: return "trackingPermission"
        case .photoPermission: return "photoPermission"
        case .featurePage: return "featurePage"
        case .completion: return "completion"
        case .search: return "search"
        }
    }
}
