//
//  ContentView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 19.12.25.
//

import SwiftUI
import CoreData
import Combine

@Observable
class ConcertsViewModel {

    // MARK: - State

    var concertToday: Concert? = nil
    var pastConcerts: [Concert] = []
    var futureConcerts: [Concert] = []
    var isLoading = false
    var isSyncing = false
    var errorMessage: String?
    var lastSyncDate: Date?

    // MARK: - Dependencies

    private let repository: OfflineConcertRepositoryProtocol
    private let syncManager: SyncManager
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Core Data

    private let coreData = CoreDataStack.shared
    private var fetchedResultsController: NSFetchedResultsController<Concert>?

    init(repository: OfflineConcertRepositoryProtocol, syncManager: SyncManager) {
        self.repository = repository
        self.syncManager = syncManager

        setupFetchedResultsController()
        observeCoreDataChanges()

        // Auto-sync on init
        Task {
            await autoSync()
        }
    }

    // MARK: - Setup

    private func setupFetchedResultsController() {
        let request: NSFetchRequest<Concert> = Concert.fetchRequest()

        // Filter out deleted
        request.predicate = NSPredicate(
            format: "syncStatus != %@",
            SyncStatus.deleted.rawValue
        )

        // Sort by date
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

        // Initial load
        updateConcerts()
    }

    private func observeCoreDataChanges() {
        // Listen to Core Data changes
        NotificationCenter.default.publisher(
            for: .NSManagedObjectContextObjectsDidChange,
            object: coreData.viewContext
        )
        .sink { [weak self] _ in
            self?.updateConcerts()
        }
        .store(in: &cancellables)
    }

    private func updateConcerts() {
        let concerts = fetchedResultsController?.fetchedObjects ?? []
            let now = Date.now

        let calendar = Calendar.current
        concertToday = concerts.first(where: { calendar.isDateInToday($0.date) })
        let concertsWithoutToday = concerts.filter {
            guard let todayId = concertToday?.id else { return true }
            return $0.id != todayId
        }

        let futureConcerts = concertsWithoutToday.filter { $0.date > now }
        let pastConcerts = concertsWithoutToday.filter { $0.date <= now }

        withAnimation {
            self.futureConcerts = futureConcerts.sorted(by: { $0.date < $1.date })
            self.pastConcerts = pastConcerts
        }
    }

    // MARK: - Actions (Always Instant!)

    func loadConcerts() {
        // ✅ Already loaded from Core Data via FetchedResultsController!
        // Just trigger a background sync
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
            errorMessage = "Sync failed: \(error.localizedDescription)"
        }
    }

    func deleteConcert(_ concert: Concert) async {
        do {
            try repository.deleteConcert(concert)
            // UI updates automatically via FetchedResultsController!
        } catch {
            errorMessage = "Delete failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Auto Sync

    private func autoSync() async {
        // Check if should sync
        guard shouldAutoSync() else { return }

        do {
            try await repository.sync()
            UserDefaults.standard.set(Date(), forKey: "lastAutoSync")
        } catch {
            logError("Auto sync failed", error: error, category: .sync)
        }
    }

    private func shouldAutoSync() -> Bool {
        // Sync max every 5 minutes
        let lastSync = UserDefaults.standard.object(forKey: "lastAutoSync") as? Date ?? .distantPast
        return Date().timeIntervalSince(lastSync) > 300
    }
}
