//
//  DependencyContainer.swift
//  concertjournal
//
//  Dependency Container - hier werden alle Dependencies erstellt und verwaltet
//

import Combine
import SwiftUI
import Supabase
import CoreData

@Observable
class DependencyContainer {

    // BFF Client
    let bffClient: BFFClient
    let coreData = CoreDataStack.shared

    // Managers (bleiben lokal)
    let supabaseClient: SupabaseClientManager
    let userSessionManager: UserSessionManagerProtocol
    let colorThemeManager: ColorThemeManager
    let storageService: StorageServiceProtocol
    let networkMonitor: NetworkMonitor
    let syncManager: SyncManager
    let tourSyncManager: TourSyncManagerProtocol
    let appState: AppState
    let buddyNotificationService: BuddyNotificationService
    let pushNotificationManager: PushNotificationManagerProtocol

    // BFF Repositories
    let offlineConcertRepository: OfflineConcertRepositoryProtocol
    let offlinePhotoRepsitory: OfflinePhotoRepositoryProtocol
    let offlineTourRepository: OfflineTourRepositoryProtocol
    let concertRepository: ConcertRepositoryProtocol
    let artistRepository: ArtistRepositoryProtocol
    let venueRepository: VenueRepositoryProtocol
    let setlistRepository: SetlistRepositoryProtocol
    let photoRepository: PhotoRepositoryProtocol
    let spotifyRepository: SpotifyRepositoryProtocol

    // Local repositories
    let faqRepository: FAQRepositoryProtocol

    var needsSetup: Bool = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        // BFF Client
        self.bffClient = BFFClient(baseURL: "https://concertjournal-bff.vercel.app")

        // Managers
        self.supabaseClient = SupabaseClientManager()
        self.userSessionManager = UserSessionManager(client: supabaseClient.client)
        self.colorThemeManager = ColorThemeManager()
        self.storageService = StorageService(supabaseClient: supabaseClient)
        self.networkMonitor = NetworkMonitor()
        self.syncManager = SyncManager(apiClient: bffClient, userSessionManager: userSessionManager)
        self.tourSyncManager = TourSyncManager(supabaseClient: supabaseClient, apiClient: bffClient, coreData: coreData)
        self.appState = AppState()
        self.buddyNotificationService = BuddyNotificationService(supabaseClient: supabaseClient, userProvider: userSessionManager)
        self.pushNotificationManager = PushNotificationManager(supabaseClient: supabaseClient)

        // ✅ BFF Client needs auth token
        self.bffClient.getAuthToken = { [weak supabaseClient] in
            guard let session = try? await supabaseClient?.client.auth.session else {
                throw BFFError.serverError("Not authenticated")
            }
            return session.accessToken
        }

        // ✅ BFF Repositories
        self.offlineConcertRepository = OfflineConcertRepository(syncManager: syncManager, userSessionManager: userSessionManager)
        self.offlinePhotoRepsitory = OfflinePhotoRepository()
        self.offlineTourRepository = OfflineTourRepository(coreDataStack: coreData, apiClient: bffClient)
        self.concertRepository = BFFConcertRepository(client: bffClient)
        self.artistRepository = BFFArtistRepository(client: bffClient)
        self.venueRepository = BFFVenueRepository(client: bffClient)
        self.setlistRepository = BFFSetlistRepository(client: bffClient)
        self.photoRepository = PhotoRepository(supabaseClient: supabaseClient, storageService: storageService)
        self.spotifyRepository = SpotifyRepository(userSessionManager: userSessionManager)

        // Local repositories (stay unchanged)
        self.faqRepository = FAQRepository(supabaseClient: supabaseClient)

        bindToAuthState()
    }

    private var previousUserId: UUID? = nil

    func bindToAuthState() {
        userSessionManager.userSessionChanged
            .sink { [weak self] user in
                guard let self else { return }
                if let user {
                    self.previousUserId = user.id
                    self.startFullSync()
                    self.checkIfUserNeedsSetup(user: user)
                    ConcertEncryptionHelper.shared.currentUserId = user.id.uuidString.lowercased()
                    self.checkiCloudKeychainOnLogin(user: user)
                    Task { await self.pushNotificationManager.registerCachedTokenIfNeeded() }
                } else {
                    guard self.previousUserId != nil else { return }
                    self.previousUserId = nil
                    nukeLocalData()
                    ConcertEncryptionHelper.shared.currentUserId = nil
                    Task { await self.pushNotificationManager.removeDeviceToken() }
                    UserDefaults.standard.removeObject(forKey: "lastSyncDate")
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: .resetAppState,
                            object: nil
                        )
                    }
                }
            }
            .store(in: &cancellables)
        
        userSessionManager.profileChanged
            .sink { [weak self] profile in
                guard let self, let profile else { return }
                self.buddyNotificationService.profile = profile
            }
            .store(in: &cancellables)
    }

    func nukeLocalData() {
        let container = CoreDataStack.shared.persistentContainer
        container.viewContext.reset()

        container.persistentStoreCoordinator.persistentStores.forEach { store in
            try? container.persistentStoreCoordinator.remove(store)
        }

        let storeURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.kuehnel.concertjournal")!
            .appendingPathComponent("CJModels.sqlite")

        try? FileManager.default.removeItem(at: storeURL)
        try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
        try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
    }
    
    private func checkIfUserNeedsSetup(user: User?) {
        guard let user = user else { return }
        let needsSetup = user.userMetadata["setup_completed"] != true
        if needsSetup {
            logInfo("User has not setup his profile yet")
            self.needsSetup = needsSetup
        }
    }
    
    func checkiCloudKeychainOnLogin(user: User?) {
        guard let user, iCloudKeychainChecker.shared.shouldShowWarning() else { return }
        
        guard user.userMetadata["icloud_warning_seen"] != true else { return }
        // Hinweis nur einmal zeigen
        iCloudKeychainChecker.shared.markWarningAsShown()
        
        // An die UI weiterleiten – z.B. über einen Publisher oder Alert
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .iCloudKeychainUnavailable,
                object: nil
            )
        }
    }

    func startFullSync() {
        Task {
            try? await syncManager.fullSync()
        }
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

extension Notification.Name {
    static let iCloudKeychainUnavailable = Notification.Name("iCloudKeychainUnavailable")
    static let syncingProblem = Notification.Name("SyncingProblem")
    static let resetAppState = Notification.Name("ResetAppState")
    static let loggedInChanged = Notification.Name("LoggedInChanged")
    static let openBuddies = Notification.Name("openBuddies")
    static let openConcert = Notification.Name("openConcert")
}
