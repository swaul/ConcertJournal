//
//  SyncManager+Photos.swift
//  concertjournal
//
//  Created by Paul Kühnel on 17.02.26.
//

import CoreData
import UIKit

// MARK: - Server Model

struct ServerPhoto: Codable {
    let id: String
    let concertVisitId: String
    let storageUrl: String      // Supabase public URL
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case concertVisitId = "concert_visit_id"
        case storageUrl     = "public_url"
        case createdAt      = "created_at"
    }
}

// MARK: - SyncManager Extension

extension SyncManager {

    // ─────────────────────────────────────────────────────────
    // Eintrittspunkt: wird aus fullSync() aufgerufen
    // ─────────────────────────────────────────────────────────

    func syncPhotos(photoRepository: OfflinePhotoRepository) async {
        do {
            try await pullPhotos()
            await photoRepository.syncPendingUploads()  // Push: lokal → server
        } catch {
            logError("Photo sync failed", error: error, category: .sync)
        }
    }

    // ─────────────────────────────────────────────────────────
    // Pull: Server → Core Data
    // ─────────────────────────────────────────────────────────

    private func pullPhotos() async throws {
        let lastSyncDate = UserDefaults.standard.object(forKey: "lastPhotoSyncDate") as? Date ?? .distantPast

        struct PhotoPullResponse: Codable {
            let photos: [ServerPhoto]
            let deleted: [String]   // Server-IDs gelöschter Photos
        }

        let response: PhotoPullResponse = try await apiClient.get(
            "/sync/photos?since=\(lastSyncDate.ISO8601Format())"
        )

        guard !response.photos.isEmpty && !response.deleted.isEmpty else {
            // Nichts zu tun
            await MainActor.run {
                UserDefaults.standard.set(Date(), forKey: "lastPhotoSyncDate")
            }
            return
        }

        let context = coreData.newBackgroundContext()

        try await context.perform {
            // Neue/geänderte Photos
            for serverPhoto in response.photos {
                try self.mergePhotoSync(serverPhoto, context: context)
            }

            // Gelöschte Photos
            for deletedId in response.deleted {
                self.deletePhotoSync(serverId: deletedId, context: context)
            }

            if context.hasChanges {
                try context.save()
            }
        }

        // Bilder im Hintergrund herunterladen (nicht blockierend)
        Task.detached(priority: .background) {
            await self.downloadMissingPhotos(from: response.photos)
        }

        await MainActor.run {
            UserDefaults.standard.set(Date(), forKey: "lastPhotoSyncDate")
        }

        logSuccess("Pulled \(response.photos.count) photos", category: .sync)
    }

    // ─────────────────────────────────────────────────────────
    // Merge: upsert Photo in Core Data
    // ─────────────────────────────────────────────────────────

    private func mergePhotoSync(_ serverPhoto: ServerPhoto, context: NSManagedObjectContext) throws {
        // Existiert das Photo schon lokal?
        let request: NSFetchRequest<Photo> = Photo.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == %@", serverPhoto.id)
        request.fetchLimit = 1

        if try context.fetch(request).first != nil {
            // Bereits vorhanden – nichts zu tun
            // (Photos ändern sich nach dem Upload nicht)
            return
        }

        // Zugehöriges Concert finden
        let concertRequest: NSFetchRequest<Concert> = Concert.fetchRequest()
        concertRequest.predicate = NSPredicate(format: "serverId == %@", serverPhoto.concertVisitId)
        concertRequest.fetchLimit = 1

        guard let concert = try context.fetch(concertRequest).first else {
            // Concert noch nicht lokal – Photo überspringen,
            // wird beim nächsten Sync nach dem Concert-Pull nachgeholt
            logDebug("Skipping photo – concert not yet local: \(serverPhoto.concertVisitId)", category: .sync)
            return
        }

        // Neues Photo-Objekt anlegen
        let photo = Photo(context: context)
        photo.id         = UUID()
        photo.serverId   = serverPhoto.id
        photo.serverUrl  = serverPhoto.storageUrl
        photo.createdAt  = serverPhoto.createdAt.supabaseStringDate ?? Date()
        photo.concert    = concert

        // Noch kein lokaler Cache → wird von downloadMissingPhotos() nachgeladen
        photo.localPath    = nil
        photo.uploadStatus = UploadStatus.uploaded.rawValue  // Kommt vom Server
        photo.syncStatus   = SyncStatus.synced.rawValue
    }

    // ─────────────────────────────────────────────────────────
    // Delete: Photo aus Core Data + Disk entfernen
    // ─────────────────────────────────────────────────────────

    private func deletePhotoSync(serverId: String, context: NSManagedObjectContext) {
        let request: NSFetchRequest<Photo> = Photo.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == %@", serverId)

        guard let photo = try? context.fetch(request).first else { return }

        // Lokale Datei löschen
        if let localPath = photo.localPath {
            try? FileManager.default.removeItem(atPath: localPath)
        }

        context.delete(photo)
    }

    // ─────────────────────────────────────────────────────────
    // Download: Fehlende lokale Dateien im Hintergrund laden
    // ─────────────────────────────────────────────────────────
    //
    // Strategie: Nur Photos die lokal noch nicht vorhanden sind
    // werden heruntergeladen. So spart man Bandbreite.

    private func downloadMissingPhotos(from serverPhotos: [ServerPhoto]) async {
        let context = coreData.newBackgroundContext()

        // IDs der Photos die noch kein localPath haben
        let missingIDs: [(objectID: NSManagedObjectID, url: String)] = await context.perform {
            serverPhotos.compactMap { serverPhoto -> (NSManagedObjectID, String)? in
                let request: NSFetchRequest<Photo> = Photo.fetchRequest()
                request.predicate = NSPredicate(
                    format: "serverId == %@ AND localPath == nil",
                    serverPhoto.id
                )
                request.fetchLimit = 1

                guard let photo = try? context.fetch(request).first else { return nil }
                return (photo.objectID, serverPhoto.storageUrl)
            }
        }

        guard !missingIDs.isEmpty else { return }

        logInfo("Downloading \(missingIDs.count) photos to disk", category: .sync)

        for (objectID, urlString) in missingIDs {
            await downloadAndCachePhoto(objectID: objectID, urlString: urlString, context: context)
        }
    }

    private func downloadAndCachePhoto(
        objectID: NSManagedObjectID,
        urlString: String,
        context: NSManagedObjectContext
    ) async {
        guard let url = URL(string: urlString) else { return }

        do {
            // Bild herunterladen
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return }

            // Konzert-ID für den lokalen Pfad holen
            let concertId: UUID? = await context.perform {
                let photo = try? context.existingObject(with: objectID) as? Photo
                return photo?.concert?.id
            }

            guard let concertId else { return }

            // Auf Disk speichern
            let photoId = await context.perform {
                (try? context.existingObject(with: objectID) as? Photo)?.id ?? UUID()
            }

            let localPath = try saveImageToDisk(image, photoId: photoId, concertId: concertId)

            // Core Data aktualisieren
            await context.perform {
                if let photo = try? context.existingObject(with: objectID) as? Photo {
                    photo.localPath = localPath
                    try? context.save()
                }
            }

            logSuccess("Photo cached: \(photoId)", category: .sync)

        } catch {
            logError("Photo download failed: \(urlString)", error: error, category: .sync)
        }
    }

    // ─────────────────────────────────────────────────────────
    // File System Helper (shared mit OfflinePhotoRepository)
    // ─────────────────────────────────────────────────────────

    private func saveImageToDisk(_ image: UIImage, photoId: UUID, concertId: UUID) throws -> String {
        let photosDir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ConcertPhotos", isDirectory: true)

        let concertDir = photosDir.appendingPathComponent(concertId.uuidString, isDirectory: true)

        try FileManager.default.createDirectory(
            at: concertDir,
            withIntermediateDirectories: true
        )

        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw PhotoError.compressionFailed
        }

        let fileName = "\(photoId.uuidString).jpg"
        let fileURL = concertDir.appendingPathComponent(fileName)
        try data.write(to: fileURL)

        // ✅ Relativen Pfad zurückgeben – stabil über App-Neustarts hinweg
        return "ConcertPhotos/\(concertId.uuidString)/\(fileName)"
    }
}
