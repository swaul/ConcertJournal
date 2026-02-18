//
//  ConcertsViewModel.swift
//  concertjournal
//

import SwiftUI
import CoreData
import Combine

@Observable
class ConcertsViewModel: NSObject, NSFetchedResultsControllerDelegate {

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

    // MARK: - Core Data

    private let coreData = CoreDataStack.shared
    private var fetchedResultsController: NSFetchedResultsController<Concert>?

    init(repository: OfflineConcertRepositoryProtocol, syncManager: SyncManager) {
        self.repository = repository
        self.syncManager = syncManager

        super.init()

        setupFetchedResultsController()

        // Auto-sync on init
        Task {
            await autoSync()
        }
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

        // ✅ Delegate setzen – so werden UI-Updates automatisch getriggert
        fetchedResultsController?.delegate = self

        try? fetchedResultsController?.performFetch()
        updateConcerts()
    }

    // MARK: - NSFetchedResultsControllerDelegate

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        updateConcerts()
    }

    // MARK: - Update from FRC

    func updateConcerts() {
        let concerts = fetchedResultsController?.fetchedObjects ?? []
        let now = Date.now
        let calendar = Calendar.current

        concertToday = concerts.first(where: { calendar.isDateInToday($0.date) })

        let concertsWithoutToday = concerts.filter {
            guard let todayId = concertToday?.id else { return true }
            return $0.id != todayId
        }

        let future = concertsWithoutToday.filter { $0.date > now }
        let past   = concertsWithoutToday.filter { $0.date <= now }

        withAnimation {
            self.futureConcerts = future.sorted(by: { $0.date < $1.date })
            self.pastConcerts   = past
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
            errorMessage = "Sync failed: \(error.localizedDescription)"
        }
    }

    func deleteConcert(_ concert: Concert) async {
        do {
            try repository.deleteConcert(concert)
            // UI aktualisiert sich automatisch via FRC Delegate
        } catch {
            errorMessage = "Delete failed: \(error.localizedDescription)"
        }
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
