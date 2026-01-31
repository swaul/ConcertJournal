//
//  DependencyContainer.swift
//  concertjournal
//
//  Dependency Container - hier werden alle Dependencies erstellt und verwaltet
//

import SwiftUI

/// Container für alle App Dependencies
class DependencyContainer {

    // MARK: - Singletons (die wirklich Singletons sein müssen)

    let supabaseClient: SupabaseClientManager
    let userSessionManager: UserSessionManager
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
    let localizationRepository: LocalizationRepository

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
            supabaseClient: supabaseClient
        )

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
