//
//  MockDependencyContainer.swift
//  concertjournal
//
//  Created by Paul Kühnel on 03.02.26.
//

import Foundation

class MockRepositoryFactory {

    // ✅ Create mocks with test data
    static func createWithTestData() -> (
        concertRepository: MockConcertRepository,
        artistRepository: MockArtistRepository,
        venueRepository: MockVenueRepository,
        spotifyRepository: MockSpotifyRepository,
        photoRepository: MockPhotoRepository,
        setlistRepository: MockSetlistRepository,
        faqRepository: MockFAQRepository
    ) {

        // Concert Repository with test data
        let concertRepo = MockConcertRepository()
        concertRepo.mockConcerts = [
            createTestConcert(
                id: "1",
                artistName: "Taylor Swift",
                date: Date().addingTimeInterval(-86400 * 30),
                rating: 5
            ),
            createTestConcert(
                id: "2",
                artistName: "Coldplay",
                date: Date().addingTimeInterval(-86400 * 60),
                rating: 4
            )
        ]

        // Artist Repository with test data
        let artistRepo = MockArtistRepository()
        artistRepo.mockArtists = [
            Artist(name: "Taylor Swift", imageUrl: nil, spotifyArtistId: "spotify1"),
            Artist(name: "Coldplay", imageUrl: nil, spotifyArtistId: "spotify2")
        ]

        // Venue Repository with test data
        let venueRepo = MockVenueRepository()
        venueRepo.mockVenues = [
            Venue(id: "V1", name: "Madison Square Garden", formattedAddress: "New York", latitude: nil, longitude: nil, appleMapsId: nil)
        ]

        // Spotify Repository with test data
        let spotifyRepo = MockSpotifyRepository()
        spotifyRepo.mockSongs = [
            SpotifySong.cruelSummer
        ]
        spotifyRepo.mockArtists = [
            SpotifyArtist.taylorSwift
        ]

        // Photo Repository
        let photoRepo = MockPhotoRepository()

        // Setlist Repository
        let setlistRepo = MockSetlistRepository()

        // FAQ Repository
        let faqRepo = MockFAQRepository()
        faqRepo.mockFAQs = [
            FAQ(id: "F1", question: "How do I add a concert?", answer: "Tap the + button")
        ]

        return (
            concertRepository: concertRepo,
            artistRepository: artistRepo,
            venueRepository: venueRepo,
            spotifyRepository: spotifyRepo,
            photoRepository: photoRepo,
            setlistRepository: setlistRepo,
            faqRepository: faqRepo
        )
    }

    // ✅ Create empty mocks
    static func createEmpty() -> (
        concertRepository: MockConcertRepository,
        artistRepository: MockArtistRepository,
        venueRepository: MockVenueRepository,
        spotifyRepository: MockSpotifyRepository,
        photoRepository: MockPhotoRepository,
        setlistRepository: MockSetlistRepository,
        faqRepository: MockFAQRepository
    ) {
        return (
            concertRepository: MockConcertRepository(),
            artistRepository: MockArtistRepository(),
            venueRepository: MockVenueRepository(),
            spotifyRepository: MockSpotifyRepository(),
            photoRepository: MockPhotoRepository(),
            setlistRepository: MockSetlistRepository(),
            faqRepository: MockFAQRepository()
        )
    }

    // Helper functions
    private static func createTestConcert(
        id: String,
        artistName: String,
        date: Date,
        rating: Int
    ) -> FullConcertVisit {
        let artist = Artist(name: artistName, imageUrl: nil, spotifyArtistId: nil)

        return FullConcertVisit(
            id: id,
            createdAt: Date(),
            updatedAt: Date(),
            date: date,
            venue: nil,
            city: "Berlin",
            rating: rating,
            title: "Amazing Concert",
            notes: "Best show ever!",
            artist: artist
        )
    }
}
