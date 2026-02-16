//
//  CreateConcertVisitViewModel.swift
//  concertjournal
//
//  Created by Paul Kühnel on 04.01.26.
//

import Supabase
import Combine
import Foundation
import UIKit

@Observable
class CreateConcertVisitViewModel: Hashable, Equatable {
    static func == (lhs: CreateConcertVisitViewModel, rhs: CreateConcertVisitViewModel) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    let id: String
    var artist: Artist?

    private let artistRepository: ArtistRepositoryProtocol
    private let setlistRepository: SetlistRepositoryProtocol
    private let concertRepository: ConcertRepositoryProtocol
    private let userSessionManager: UserSessionManagerProtocol
    private let photoRepository: PhotoRepositoryProtocol

    init(artist: Artist? = nil,
         artistRepository: ArtistRepositoryProtocol,
         concertRepository: ConcertRepositoryProtocol,
         userSessionManager: UserSessionManagerProtocol,
         photoRepository: PhotoRepositoryProtocol,
         setlistRepository: SetlistRepositoryProtocol) {
        self.artistRepository = artistRepository
        self.concertRepository = concertRepository
        self.photoRepository = photoRepository
        self.userSessionManager = userSessionManager
        self.setlistRepository = setlistRepository

        self.artist = artist
        self.id = UUID().uuidString
    }

    func createVisit(from new: NewConcertVisit, selectedImages: [UIImage] = []) async throws -> CreationResponse {
        guard let artist else { throw URLError(.notConnectedToInternet) }
        let createArtist = CreateArtistDTO(artist: artist)
        let artistResponse = try await artistRepository.getOrCreateArtist(createArtist)

        let supportActs = await self.uploadSupportActs(artists: new.supportActs)

        guard let userId = userSessionManager.user?.id.uuidString else { throw URLError(.notConnectedToInternet) }
        let newConcert = NewConcertDTO(with: new, supportActsIds: supportActs.map { $0.id }, by: userId, with: artistResponse.id)

        // CRITICAL: Das Konzert MUSS erfolgreich erstellt werden
        // Wenn das fehlschlägt, wird ein Error geworfen
        let concert = try await concertRepository.createConcert(newConcert)

        // Thread-safe Response Collector
        let responseCollector = ResponseCollector()
        let items = new.setlistItems.map { CreateSetlistItemDTO(concertId: concert.id, item: $0) }

        // Optionale Uploads parallel ausführen
        await withTaskGroup(of: Void.self) { group in
            // Setlist Upload (optional)
            if !new.setlistItems.isEmpty {
                group.addTask {
                    await self.uploadSetlistItems(responseCollector: responseCollector, items: items)
                }
            }

            // Photos Upload (optional)
            if !selectedImages.isEmpty {
                group.addTask {
                    await self.uploadSelectedPhotos(responseCollector: responseCollector, selectedImages: selectedImages, visitId: concert.id)
                }
            }
        }

        // Response aus dem Collector holen
        return await responseCollector.getResponse()
    }

    private func uploadSupportActs(artists: [Artist]) async -> [Artist] {
        do {
            var uploadedArtists: [Artist] = []
            for artist in artists {
                let createArtist = CreateArtistDTO(artist: artist)
                let artistResponse = try await artistRepository.getOrCreateArtist(createArtist)
                uploadedArtists.append(artistResponse)
            }

            return uploadedArtists
        } catch {
            logError("Failed adding support acts: \(error)")
            return []
        }
    }

    private func uploadSetlistItems(responseCollector: ResponseCollector, items: [CreateSetlistItemDTO]) async {
        do {
            for item in items {
                let result = try await setlistRepository.createSetlistItem(item)
                logSuccess("Created setlist item \(result.title)")
            }
        } catch {
            await responseCollector.addProblem("Setlist konnte nicht hochgeladen werden")
            logError("Failed creating setlist items: \(error)")
        }
    }

    private func uploadSelectedPhotos(responseCollector: ResponseCollector, selectedImages: [UIImage], visitId: String) async {
        guard let userId = userSessionManager.user?.id.uuidString else {
            await responseCollector.addProblem("Fotos konnten nicht hochgeladen werden")
            return
        }

        do {
            for image in selectedImages {
                _ = try await photoRepository.uploadPhoto(image: image, concertVisitId: visitId, userId: userId)
                logSuccess("Uploaded Photo")
            }
        } catch {
            await responseCollector.addProblem("Fotos konnten nicht hochgeladen werden")
            logError("Failed uploading photos: \(error)")
        }
    }
}

// MARK: - Response Types

struct CreationResponse {
    var problems: [String] = []

    var success: Bool {
        problems.isEmpty
    }

    var hasWarnings: Bool {
        !problems.isEmpty
    }
}

// Thread-safe Actor für parallele Problem-Collection
actor ResponseCollector {
    private var problems: [String] = []

    func addProblem(_ problem: String) {
        problems.append(problem)
    }

    func getResponse() -> CreationResponse {
        CreationResponse(problems: problems)
    }
}

struct ConcertVisitIdDTO: Codable {
    let id: String
}
