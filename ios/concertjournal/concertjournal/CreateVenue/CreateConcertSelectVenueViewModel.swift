//
//  CreateConcertSelectVenueViewModel.swift
//  concertjournal
//
//  Created by Paul Kühnel on 03.01.26.
//

import Foundation
import MapKit
import Combine
import Supabase

@MainActor
final class VenueSearchViewModel: ObservableObject {
    
    @Published var query: String = ""
    @Published var results: [MKMapItem] = []
    @Published var isLoading = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        $query
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] value in
                guard value.count >= 2 else {
                    self?.results = []
                    return
                }
                self?.search(query: value)
            }
            .store(in: &cancellables)
    }
    
    func search(query: String) {
        isLoading = true
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .pointOfInterest
        
        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, _ in
            Task { @MainActor in
                self?.isLoading = false
                self?.results = response?.mapItems ?? []
            }
        }
    }
    
    func saveVenue(venue: MKMapItem) async throws -> Venue {
        guard let name = venue.name else { throw CancellationError() }
        
        let venue = Venue(id: "",
                          name: name,
                          city: venue.addressRepresentations?.cityName,
                          formattedAddress: venue.addressRepresentations?.fullAddress(includingRegion: false, singleLine: true) ?? "",
                          latitude: venue.location.coordinate.latitude,
                          longitude: venue.location.coordinate.longitude,
                          appleMapsId: venue.identifier?.rawValue)
        
        let venueId: String
        
        let existingVenueId: String?
        if let appleMapsId = venue.appleMapsId {
            // Get-or-create artist by spotify_artist_id (must match your DB column type)
            let existingVenue: [Venue] = try await SupabaseManager.shared.client
                .from("venues")
                .select()
                .eq("apple_maps_id", value: appleMapsId)
                .execute()
                .value
            
            existingVenueId = existingVenue.first?.id
        } else {
            let existingVenue: [Venue] = try await SupabaseManager.shared.client
                .from("venues")
                .select()
                .eq("name", value: venue.name)
                .execute()
                .value
            
            existingVenueId = existingVenue.first?.id
        }
        
        if let existingVenueId {
            venueId = existingVenueId
        } else {
            // Insert artist and prefer returning the inserted row to get canonical id
            let venueData = venue.toData
            let inserted: Venue = try await SupabaseManager.shared.client
                .from("venues")
                .insert(venueData)
                .select()
                .single()
                .execute()
                .value
            
            venueId = inserted.id
        }
        
        return Venue(id: venueId,
                     name: name,
                     city: venue.city,
                     formattedAddress: venue.formattedAddress,
                     latitude: venue.latitude,
                     longitude: venue.longitude,
                     appleMapsId: venue.appleMapsId)
    }
}

public struct Venue: Codable, Equatable {
    var id: String
    var name: String
    var city: String?
    var formattedAddress: String
    var latitude: Double?
    var longitude: Double?
    var appleMapsId: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case city
        case formattedAddress = "formatted_address"
        case latitude
        case longitude
        case appleMapsId = "apple_maps_id"
    }
    
    var toData: [String: AnyJSON] {
        let venueDTO = VenueDTO(venue: self)
        
        return venueDTO.toData
    }
    
    struct VenueDTO: Codable {
        var name: String
        var formattedAddress: String
        var latitude: Double?
        var longitude: Double?
        var appleMapsId: String?
        
        enum CodingKeys: String, CodingKey {
            case name
            case formattedAddress = "formatted_address"
            case latitude
            case longitude
            case appleMapsId = "apple_maps_id"
        }
        
        init(venue: Venue) {
            name = venue.name
            formattedAddress = venue.formattedAddress
            latitude = venue.latitude
            longitude = venue.longitude
            appleMapsId = venue.appleMapsId
        }
        
        var toData: [String: AnyJSON] {
            var data: [String: AnyJSON] = [
                "name": .string(name),
                "formatted_address": .string(formattedAddress)
            ]
            
            if let latitude {
                data["latitude"] = .double(latitude)
            } else {
                data["latitude"] = .null
            }
            if let longitude {
                data["longitude"] = .double(longitude)
            } else {
                data["longitude"] = .null
            }
            if let appleMapsId {
                data["apple_maps_id"] = .string(appleMapsId)
            } else {
                data["apple_maps_id"] = .null
            }
            
            return data
        }
    }
}
