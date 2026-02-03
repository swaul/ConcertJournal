//
//  DependencyContainer.swift
//  concertjournal
//
//  Dependency Container - hier werden alle Dependencies erstellt und verwaltet
//

import SwiftUI

protocol DependencyContainerProtocol {
    var supabaseClient: SupabaseClientManagerProtocol { get }
    var userSessionManager: UserSessionManagerProtocol { get }
    var colorThemeManager: ColorThemeManager { get }
    var networkService: NetworkServiceProtocol { get }
    var storageService: StorageServiceProtocol { get }
    var concertRepository: ConcertRepositoryProtocol { get }
    var venueRepository: VenueRepositoryProtocol { get }
    var artistRepository: ArtistRepositoryProtocol { get }
    var spotifyRepository: SpotifyRepositoryProtocol { get }
    var photoRepository: PhotoRepositoryProtocol { get }
    var faqRepository: FAQRepositoryProtocol { get }
    var setlistRepository: SetlistRepositoryProtocol { get }
    var localizationRepository: LocalizationRepositoryProtocol { get }
}

class DependencyContainer: DependencyContainerProtocol {

    // MARK: - Singletons (die wirklich Singletons sein müssen)

    let supabaseClient: SupabaseClientManagerProtocol
    let userSessionManager: UserSessionManagerProtocol
    let colorThemeManager: ColorThemeManager

    // MARK: - Services

    let networkService: NetworkServiceProtocol
    let storageService: StorageServiceProtocol

    // MARK: - Repositories

    let concertRepository: ConcertRepositoryProtocol
    let venueRepository: VenueRepositoryProtocol
    let artistRepository: ArtistRepositoryProtocol
    let spotifyRepository: SpotifyRepositoryProtocol
    let photoRepository: PhotoRepositoryProtocol
    let faqRepository: FAQRepositoryProtocol
    let setlistRepository: SetlistRepositoryProtocol
    let localizationRepository: LocalizationRepositoryProtocol

    // MARK: - Initialization

    init() {
        // 1. Supabase Client
        self.supabaseClient = SupabaseClientManager()

        // 2. Managers
        self.userSessionManager = UserSessionManager(client: supabaseClient.client)
        self.colorThemeManager = ColorThemeManager()

        // 3. Network Service
        self.networkService = NetworkService(client: supabaseClient.client)
        self.storageService = StorageService(supabaseClient: supabaseClient)

        // 4. Repositories
        self.concertRepository = ConcertRepository(
            networkService: networkService,
            userSessionManager: userSessionManager,
            supabaseClient: supabaseClient
        )

        self.setlistRepository = SetlistRepository(supabaseClient: supabaseClient,
                                                  networkService: networkService)

        self.artistRepository = ArtistRepository(supabaseClient: supabaseClient,
                                                 networkService: networkService)

        self.photoRepository = PhotoRepository(supabaseClient: supabaseClient,
                                               storageService: storageService)

        self.spotifyRepository = SpotifyRepository(supabaseClient: supabaseClient)

        self.faqRepository = FAQRepository(supabaseClient: supabaseClient)
        self.localizationRepository = LocalizationRepository(supabaseClient: supabaseClient)
        self.venueRepository = VenueRepository(supabaseClient: supabaseClient,
                                               networkService: networkService)
    }
}

// MARK: - Environment Key für Dependency Injection

private struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue = DependencyContainer()
}

extension EnvironmentValues {
    var dependencies: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}

// MARK: - View Extension für einfachen Zugriff

extension View {
    func withDependencies(_ container: DependencyContainer) -> some View {
        self.environment(\.dependencies, container)
    }
}
