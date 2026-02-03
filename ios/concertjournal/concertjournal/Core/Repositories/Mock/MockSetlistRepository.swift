//
//  MockSetlistRepository.swift
//  concertjournal
//
//  Created by Paul Kühnel on 03.02.26.
//

import Foundation

class MockSetlistRepository: SetlistRepositoryProtocol {

    var shouldFail = false
    var failureError: Error = NetworkError.unknownError
    var delay: TimeInterval = 0

    var mockSetlistItems: [SetlistItem] = []

    func createSetlistItem(_ setlistItem: CeateSetlistItemDTO) async throws -> SetlistItem {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldFail {
            throw failureError
        }

        let item = SetlistItem(
            id: UUID().uuidString,
            concertVisitId: setlistItem.concertVisitId,
            position: setlistItem.position,
            section: setlistItem.section,
            spotifyTrackId: setlistItem.spotifyTrackId,
            title: setlistItem.title,
            artistNames: setlistItem.artistNames,
            albumName: setlistItem.albumName,
            coverImage: setlistItem.coverImage,
            notes: setlistItem.notes ?? "",
            createdAt: Date()
        )

        mockSetlistItems.append(item)
        return item
    }

    func getSetlistItems(with concertId: String) async throws -> [SetlistItem] {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldFail {
            throw failureError
        }

        return mockSetlistItems
            .filter { $0.concertVisitId == concertId }
            .sorted { $0.position < $1.position }
    }

    func deleteSetlistItem(_ setlistItemId: String) async throws {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldFail {
            throw failureError
        }

        mockSetlistItems.removeAll { $0.id == setlistItemId }
    }
}
