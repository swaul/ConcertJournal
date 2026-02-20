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
    var artist: ArtistDTO?
    
    private let repository: OfflineConcertRepositoryProtocol
    private let photoRepository: OfflinePhotoRepositoryProtocol
    private let notificationService: BuddyNotificationService
    
    init(artist: ArtistDTO? = nil,
         repository: OfflineConcertRepositoryProtocol,
         photoRepository: OfflinePhotoRepositoryProtocol,
         notificationService: BuddyNotificationService) {
        self.repository = repository
        self.photoRepository = photoRepository
        self.notificationService = notificationService
        
        self.artist = artist
        self.id = UUID().uuidString
    }
    
    func createVisit(from new: NewConcertVisit, selectedImages: [UIImage] = []) async throws {
        guard let newConcert = CreateConcertDTO(newConcertVisit: new, images: selectedImages) else {
            throw CreateConcertError.couldNotCreateConcertDTO
        }
        
        let concert = try repository.createConcert(newConcert)
        
        await notificationService.notifyBuddies(
            attendees: new.buddyAttendees,
            concertId: concert.id.uuidString.lowercased(),
            concertTitle: new.artistName
        )
        
        for photo in selectedImages {
            _ = try photoRepository.savePhoto(photo, for: concert)
        }
    }
}

enum CreateConcertError: Error {
    case couldNotCreateConcertDTO
}
