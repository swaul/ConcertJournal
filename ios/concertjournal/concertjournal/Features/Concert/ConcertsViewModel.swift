//
//  ConcertsViewModel.swift
//  concertjournal
//

import SwiftUI
import CoreData
import Combine

@Observable
class ConcertsViewModel: NSObject {

    // MARK: - State

    var concertToday: Concert? = nil
    var allConcerts: [Concert] = []
    var futureConcerts: [Concert] = []
    var isLoading = false
    var isSyncing = false
    var errorMessage: ErrorMessage?
    var lastSyncDate: Date?
    
    var hasTours: Bool = false

    // MARK: - Dependencies

    private let repository: OfflineConcertRepositoryProtocol
    private let syncManager: SyncManager

    // MARK: - Core Data

    private let coreData = CoreDataStack.shared
    private var fetchedResultsController: NSFetchedResultsController<Concert>?

    private var cancellables = Set<AnyCancellable>()

    init(repository: OfflineConcertRepositoryProtocol, syncManager: SyncManager) {
        self.repository = repository
        self.syncManager = syncManager

        super.init()

        setupFetchedResultsController()

        // Auto-sync on init
        Task {
            await autoSync()
        }
        
        coreData.didChange
            .sink { [weak self] in
                guard let self else { return }
                try? self.fetchedResultsController?.performFetch()
                self.updateConcerts()
            }
            .store(in: &cancellables)
    }

    // MARK: - Setup

    private func setupFetchedResultsController() {
        let request: NSFetchRequest<Concert> = Concert.fetchRequest()

        request.predicate = NSPredicate(
            format: "syncStatus != %@",
            SyncStatus.deleted.rawValue
        )

        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Concert.date, ascending: false)
        ]

        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: coreData.viewContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )

        try? fetchedResultsController?.performFetch()
        updateConcerts()
    }

    // MARK: - Update from FRC

    func updateConcerts() {
        let concerts = fetchedResultsController?.fetchedObjects ?? []
        let now = Date.now
        let calendar = Calendar.current

        concertToday = concerts.first(where: { calendar.isDateInToday($0.date) })
        hasTours = concerts.contains(where: { $0.tour != nil })

        let concertsWithoutToday = concerts.filter {
            guard let todayId = concertToday?.id else { return true }
            return $0.id != todayId
        }

        let future = concertsWithoutToday.filter { $0.date > now }

        withAnimation {
            self.futureConcerts = future.sorted(by: { $0.date < $1.date })
            self.allConcerts    = concertsWithoutToday
        }
    }

    // MARK: - Actions

    func loadConcerts() {
        Task {
            await autoSync()
        }
    }

    func refreshConcerts() async {
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await repository.sync()
            lastSyncDate = Date()
        } catch {
            isSyncing = false
            errorMessage = ErrorMessage(message: TextKey.homeSyncFailed.localized)
        }
    }

    func deleteConcert(_ concert: Concert) async {
        do {
            try repository.deleteConcert(concert.objectID)
        } catch {
            errorMessage = ErrorMessage(message: TextKey.homeDeletionFailed.localized)
        }
    }

    @MainActor
    func reset() {
        isSyncing = false
        concertToday = nil
        allConcerts = []
        futureConcerts = []
    }

    // MARK: - Auto Sync

    private func autoSync() async {
        guard shouldAutoSync() else { return }

        do {
            try await repository.sync()
            UserDefaults.standard.set(Date(), forKey: "lastAutoSync")
        } catch {
            logError("Auto sync failed", error: error, category: .sync)
        }
    }

    private func shouldAutoSync() -> Bool {
        let lastSync = UserDefaults.standard.object(forKey: "lastAutoSync") as? Date ?? .distantPast
        return Date().timeIntervalSince(lastSync) > 300
    }
}
