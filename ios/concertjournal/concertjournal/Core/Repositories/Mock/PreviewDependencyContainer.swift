//
//  PreviewDependencyContainer.swift
//  concertjournal
//
//  Created by Paul Kühnel on 03.02.26.
//

import SwiftUI

class PreviewDependencyContainer: DependencyContainerProtocol {

    // Mock Repositories
    let concertRepository: ConcertRepositoryProtocol
    let artistRepository: ArtistRepositoryProtocol
    let venueRepository: VenueRepositoryProtocol
    let spotifyRepository: SpotifyRepositoryProtocol
    let photoRepository: PhotoRepositoryProtocol
    let setlistRepository: SetlistRepositoryProtocol
    let faqRepository: FAQRepositoryProtocol
    let localizationRepository: LocalizationRepositoryProtocol

    // Managers (can be real or mock)
    let networkService: NetworkServiceProtocol
    let supabaseClient: SupabaseClientManagerProtocol
    let userSessionManager: UserSessionManagerProtocol
    let colorThemeManager: ColorThemeManager
    let storageService: StorageServiceProtocol

    init(scenario: PreviewScenario = .happyPath) {
        // Real managers (lightweight)
        let supabaseClient = MockSupabaseClientManager()
        self.supabaseClient = supabaseClient
        self.networkService = NetworkService(client: supabaseClient.client)
        self.storageService = StorageService(supabaseClient: supabaseClient)
        self.userSessionManager = MockUserSessionManager()
        self.colorThemeManager = ColorThemeManager()

        // Mock repositories based on scenario
        switch scenario {
        case .happyPath:
            let mocks = MockRepositoryFactory.createWithTestData()
            print(mocks.concertRepository.mockConcerts)
            self.concertRepository = mocks.concertRepository
            self.artistRepository = mocks.artistRepository
            self.venueRepository = mocks.venueRepository
            self.spotifyRepository = mocks.spotifyRepository
            self.photoRepository = mocks.photoRepository
            self.setlistRepository = mocks.setlistRepository
            self.faqRepository = mocks.faqRepository

        case .empty:
            let mocks = MockRepositoryFactory.createEmpty()
            self.concertRepository = mocks.concertRepository
            self.artistRepository = mocks.artistRepository
            self.venueRepository = mocks.venueRepository
            self.spotifyRepository = mocks.spotifyRepository
            self.photoRepository = mocks.photoRepository
            self.setlistRepository = mocks.setlistRepository
            self.faqRepository = mocks.faqRepository

        case .loading:
            let mocks = MockRepositoryFactory.createWithTestData()
            mocks.concertRepository.delay = 2.0
            mocks.artistRepository.delay = 2.0
            self.concertRepository = mocks.concertRepository
            self.artistRepository = mocks.artistRepository
            self.venueRepository = mocks.venueRepository
            self.spotifyRepository = mocks.spotifyRepository
            self.photoRepository = mocks.photoRepository
            self.setlistRepository = mocks.setlistRepository
            self.faqRepository = mocks.faqRepository

        case .error:
            let mocks = MockRepositoryFactory.createEmpty()
            mocks.concertRepository.shouldFail = true
            mocks.concertRepository.failureError = NetworkError.serverError("Mock error")
            self.concertRepository = mocks.concertRepository
            self.artistRepository = mocks.artistRepository
            self.venueRepository = mocks.venueRepository
            self.spotifyRepository = mocks.spotifyRepository
            self.photoRepository = mocks.photoRepository
            self.setlistRepository = mocks.setlistRepository
            self.faqRepository = mocks.faqRepository

        case .custom(let customMocks):
            self.concertRepository = customMocks.concertRepository
            self.artistRepository = customMocks.artistRepository
            self.venueRepository = customMocks.venueRepository
            self.spotifyRepository = customMocks.spotifyRepository
            self.photoRepository = customMocks.photoRepository
            self.setlistRepository = customMocks.setlistRepository
            self.faqRepository = customMocks.faqRepository
        }

        self.localizationRepository = LocalizationRepository(supabaseClient: supabaseClient)
    }

    enum PreviewScenario {
        case happyPath
        case empty
        case loading
        case error
        case custom(CustomMocks)
    }

    struct CustomMocks {
        let concertRepository: ConcertRepositoryProtocol
        let artistRepository: ArtistRepositoryProtocol
        let venueRepository: VenueRepositoryProtocol
        let spotifyRepository: SpotifyRepositoryProtocol
        let photoRepository: PhotoRepositoryProtocol
        let setlistRepository: SetlistRepositoryProtocol
        let faqRepository: FAQRepositoryProtocol
    }
}

private struct PreviewDependencyContainerKey: EnvironmentKey {
    static let defaultValue = PreviewDependencyContainer()
}

extension EnvironmentValues {
    var previewDependencies: PreviewDependencyContainer {
        get { self[PreviewDependencyContainerKey.self] }
        set { self[PreviewDependencyContainerKey.self] = newValue }
    }
}

extension View {
    func withDependencies(_ container: PreviewDependencyContainer) -> some View {
        self.environment(\.previewDependencies, container)
    }
}
