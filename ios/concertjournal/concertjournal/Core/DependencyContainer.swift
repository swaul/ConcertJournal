//
//  DependencyContainer.swift
//  concertjournal
//
//  Dependency Container - hier werden alle Dependencies erstellt und verwaltet
//

import SwiftUI
import Supabase

class DependencyContainer {
    
    // BFF Client
    let bffClient: BFFClient
    let coreDataStack: CoreDataStack

    // Managers (bleiben lokal)
    let supabaseClient: SupabaseClientManager
    let userSessionManager: UserSessionManagerProtocol
    let colorThemeManager: ColorThemeManager
    let storageService: StorageServiceProtocol
    let syncManager: SyncManager

    // ✅ BFF Repositories
    let offlineConcertRepository: OfflineConcertRepositoryProtocol
    let concertRepository: ConcertRepositoryProtocol
    let artistRepository: ArtistRepositoryProtocol
    let venueRepository: VenueRepositoryProtocol
    let setlistRepository: SetlistRepositoryProtocol
    let photoRepository: PhotoRepositoryProtocol
    let spotifyRepository: SpotifyRepositoryProtocol
    
    // Local repositories
    let faqRepository: FAQRepositoryProtocol
    let localizationRepository: LocalizationRepository
    
    init() {
        // BFF Client
        self.bffClient = BFFClient(baseURL: "https://concertjournal-bff.vercel.app")
        self.coreDataStack = CoreDataStack()

        // Managers
        self.supabaseClient = SupabaseClientManager()
        self.userSessionManager = UserSessionManager(client: supabaseClient.client)
        self.colorThemeManager = ColorThemeManager()
        self.storageService = StorageService(supabaseClient: supabaseClient)
        self.syncManager = SyncManager(apiClient: bffClient, coreData: coreDataStack)

        // ✅ BFF Client needs auth token
        self.bffClient.getAuthToken = { [weak supabaseClient] in
            guard let session = try? await supabaseClient?.client.auth.session else {
                throw BFFError.serverError("Not authenticated")
            }
            return session.accessToken
        }
        
        // ✅ BFF Repositories
        self.offlineConcertRepository = OfflineConcertRepository(syncManager: syncManager)
        self.concertRepository = BFFConcertRepository(client: bffClient)
        self.artistRepository = BFFArtistRepository(client: bffClient)
        self.venueRepository = BFFVenueRepository(client: bffClient)
        self.setlistRepository = BFFSetlistRepository(client: bffClient)
        self.photoRepository = PhotoRepository(supabaseClient: supabaseClient, storageService: storageService)
        self.spotifyRepository = SpotifyRepository(userSessionManager: userSessionManager)
        
        // Local repositories (stay unchanged)
        self.faqRepository = FAQRepository(supabaseClient: supabaseClient)
        self.localizationRepository = LocalizationRepository(supabaseClient: supabaseClient)
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
