//
//  OfflinePhotoRepository.swift
//  concertjournal
//

import UIKit
import CoreData

// MARK: - Protocol

protocol OfflinePhotoRepositoryProtocol {
    func savePhoto(_ image: UIImage, for concertId: NSManagedObjectID) throws -> Photo
    func deletePhoto(_ photo: Photo) throws
    func loadImage(for photo: Photo) -> UIImage?
    func syncPendingUploads() async
}

// MARK: - Upload Status

enum UploadStatus: String {
    case local       // Only on device
    case uploading   // Currently uploading
    case uploaded    // On server
    case failed      // Upload failed
}

// MARK: - Implementation

class OfflinePhotoRepository: OfflinePhotoRepositoryProtocol {

    private let coreData = CoreDataStack.shared

    // Absolutes Basisverzeichnis – berechnet, nie gespeichert
    private var photosDirectory: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ConcertPhotos", isDirectory: true)
    }

    // MARK: - Save (Offline-First)

    /// Saves image to disk + Core Data immediately.
    /// Upload to server happens in background via syncPendingUploads()
    func savePhoto(_ image: UIImage, for concertId: NSManagedObjectID) throws -> Photo {
        let context = coreData.viewContext
        let concert = try context.existingObject(with: concertId) as! Concert

        // 1. Create Core Data object first
        let photo = Photo(context: context)
        photo.id = UUID()
        photo.createdAt = Date()
        photo.concert = concert
        photo.uploadStatus = UploadStatus.local.rawValue
        photo.syncStatus = SyncStatus.pending.rawValue

        // 2. Save to file system – store RELATIVE path
        let relativePath = try saveImageToDisk(image, photoId: photo.id, concertId: concert.id)
        photo.localPath = relativePath   // z.B. "ConcertPhotos/<concertId>/<photoId>.jpg"

        // 3. Save Core Data
        try coreData.saveWithResult()

        logSuccess("Photo saved locally: \(relativePath)", category: .repository)

        return photo
    }

    // MARK: - Delete

    func deletePhoto(_ photo: Photo) throws {
        // 1. Delete local file
        if let relativePath = photo.localPath {
            let url = absoluteURL(for: relativePath)
            try? FileManager.default.removeItem(at: url)
        }

        // 2. If uploaded: mark for server deletion
        if photo.serverUrl != nil {
            photo.syncStatus = SyncStatus.deleted.rawValue
            photo.uploadStatus = UploadStatus.local.rawValue
            try coreData.saveWithResult()
        } else {
            coreData.viewContext.delete(photo)
            try coreData.saveWithResult()
        }
    }

    // MARK: - Load Image

    /// Loads image from local path (fast, no network).
    /// localPath is stored as a relative path to keep it stable across app restarts.
    func loadImage(for photo: Photo) -> UIImage? {
        if let relativePath = photo.localPath {
            let url = absoluteURL(for: relativePath)
            if let data = try? Data(contentsOf: url) {
                return UIImage(data: data)
            }
        }
        // Falls kein lokales File, wird AsyncImage den serverUrl laden
        return nil
    }

    // MARK: - Sync Pending Uploads

    func syncPendingUploads() async {
        let context = coreData.newBackgroundContext()

        let pendingIDs = await context.perform {
            let request: NSFetchRequest<Photo> = Photo.fetchRequest()
            request.predicate = NSPredicate(
                format: "uploadStatus == %@ AND localPath != nil",
                UploadStatus.local.rawValue
            )
            let photos = try? context.fetch(request)
            return photos?.map { $0.objectID } ?? []
        }

        for photoID in pendingIDs {
            await uploadPhoto(photoID: photoID, context: context)
        }
    }

    private func uploadPhoto(photoID: NSManagedObjectID, context: NSManagedObjectContext) async {
        let uploadData = await context.perform { () -> (relativePath: String, concertServerId: String?)? in
            guard let photo = try? context.existingObject(with: photoID) as? Photo,
                  let relativePath = photo.localPath else { return nil }

            photo.uploadStatus = UploadStatus.uploading.rawValue
            try? context.save()

            return (relativePath, photo.concert?.serverId)
        }

        guard let uploadData = uploadData,
              let concertServerId = uploadData.concertServerId else {
            logDebug("Skipping photo upload – concert not yet on server", category: .repository)
            return
        }

        do {
            // Absoluten Pfad zur Laufzeit berechnen
            let fileURL = absoluteURL(for: uploadData.relativePath)
            guard let imageData = try? Data(contentsOf: fileURL),
                  let image = UIImage(data: imageData) else {
                logError("Could not load image from disk", category: .repository)
                return
            }

            let serverUrl = try await uploadToSupabase(
                image: image,
                concertServerId: concertServerId
            )

            await context.perform {
                if let photo = try? context.existingObject(with: photoID) as? Photo {
                    photo.serverUrl = serverUrl
                    photo.uploadStatus = UploadStatus.uploaded.rawValue
                    photo.syncStatus = SyncStatus.synced.rawValue
                    try? context.save()
                }
            }

            logSuccess("Photo uploaded: \(serverUrl)", category: .repository)

        } catch {
            await context.perform {
                if let photo = try? context.existingObject(with: photoID) as? Photo {
                    photo.uploadStatus = UploadStatus.failed.rawValue
                    try? context.save()
                }
            }
            logError("Photo upload failed", error: error, category: .repository)
        }
    }

    // MARK: - File System Helpers

    /// Speichert das Bild und gibt den RELATIVEN Pfad zurück
    /// (z.B. "ConcertPhotos/<concertId>/<photoId>.jpg")
    private func saveImageToDisk(_ image: UIImage, photoId: UUID, concertId: UUID) throws -> String {
        let concertDir = photosDirectory.appendingPathComponent(concertId.uuidString, isDirectory: true)

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

    /// Berechnet den absoluten URL aus dem gespeicherten relativen Pfad
    private func absoluteURL(for relativePath: String) -> URL {
        // Legacy-Support: falls alter absoluter Pfad gespeichert ist
        if relativePath.hasPrefix("/") {
            return URL(fileURLWithPath: relativePath)
        }
        return FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(relativePath)
    }

    private func uploadToSupabase(image: UIImage, concertServerId: String) async throws -> String {
        fatalError("Implement with your StorageService")
    }

    // MARK: - Cleanup

    func deleteLocalFile(for photo: Photo) throws {
        guard photo.uploadStatus == UploadStatus.uploaded.rawValue,
              let relativePath = photo.localPath else { return }

        let url = absoluteURL(for: relativePath)
        try FileManager.default.removeItem(at: url)

        photo.localPath = nil
        try coreData.saveWithResult()

        logInfo("Local file deleted after upload", category: .repository)
    }
}

// MARK: - Errors

enum PhotoError: Error {
    case compressionFailed
    case fileNotFound
    case uploadFailed
}
