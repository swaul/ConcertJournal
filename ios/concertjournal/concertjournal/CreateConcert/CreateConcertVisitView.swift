import Combine
import SwiftUI
import Supabase
import SpotifyiOS

struct NewConcertVisit: Identifiable, Equatable {
    let id: UUID = UUID()
    var date: Date = .now
    var artistName: String = ""
    var venue: String = ""
    var city: String = ""
    var title: String = ""
    var notes: String = ""
    var rating: Int = 0
}

struct SpotifyArtistSearchResponse: Codable {
    let artists: SpotifyArtistsResponse
}

// MARK: - Artists
struct SpotifyArtistsResponse: Codable {
    let href: String?
    let limit: Int?
    let next: String?
    let offset: Int?
    let previous: String?
    let total: Int?
    let items: [SpotifyArtist]
}

// MARK: - Item
struct SpotifyArtist: Codable, Identifiable {
    let externalUrls: ExternalUrls?
    let followers: Followers?
    let genres: [String]?
    let href, id: String?
    let images: [SpotifyImage]?
    let name: String
    let popularity: Int?
    let type, uri: String?

    enum CodingKeys: String, CodingKey {
        case externalUrls = "external_urls"
        case followers, genres, href, id, images, name, popularity, type, uri
    }
}

// MARK: - ExternalUrls
struct ExternalUrls: Codable {
    let spotify: String?
}

// MARK: - Followers
struct Followers: Codable {
    let href: String?
    let total: Int?
}

// MARK: - Image
struct SpotifyImage: Codable {
    let url: String?
    let height, width: Int?
}


struct CreateConcertSelectArtistView: View {
    
    @StateObject var viewModel = CreateConcertSelectArtistViewModel()
    @State var artistName: String = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(viewModel.artistsResponse) {
                    makeArtistView(artist: $0)
                        .background {
                            Color.black
                        }
                        .cornerRadius(10)
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            VStack {
                TextField(text: $artistName) {
                    Text("Select an artist")
                }
                .submitLabel(.search)
                .onSubmit {
                    viewModel.searchArtists(with: artistName)
                }
                .padding()
            }
            .glassEffect()
            .padding(.horizontal)
        }
    }
    
    func makeArtistView(artist: SpotifyArtist) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(artist.name)
                    .bold()
                Text("Follower: \(artist.followers?.total ?? 0)")
                Text(artist.genres?.joined(separator: ", ") ?? "")
            }
            .padding()
            Spacer()
            if let url = artist.images?.first?.url {
                AsyncImage(url: URL(string: url)) { result in
                    result.image?
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100)
                }
            }
        }
        .foregroundStyle(.white)
    }
    
}

class CreateConcertSelectArtistViewModel: ObservableObject {
    
    @Published var artistsResponse: [SpotifyArtist] = []

    struct SpotifyTokenResponse: Codable {
        let accessToken: String

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
        }
    }

    func fetchSpotifyToken() async throws -> String {
        let response: SpotifyTokenResponse = try await SupabaseManager.shared.client.functions
          .invoke("smart-worker")
        
        return response.accessToken
    }
    
    func searchArtists(with text: String) {
        Task {
            guard let url = makeSpotifySearchURL(query: text) else {
                throw URLError(.badURL)
            }
            
            do {
                let token = try await fetchSpotifyToken()
                
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                
                let (data, _) = try await URLSession.shared.data(for: request)
                let result = try JSONDecoder().decode(SpotifyArtistSearchResponse.self, from: data)
                artistsResponse = result.artists.items
            } catch {
                print("Could not complete search for \(text);", error)
            }
        }
    }
    
    func makeSpotifySearchURL(query: String,
                              limit: Int = 10) -> URL? {

        var components = URLComponents(string: "https://api.spotify.com/v1/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "artist"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "market", value: "DE")
        ]

        return components?.url
    }
}

struct CreateConcertVisitView: View {
    @Environment(\.dismiss) private var dismiss

    // Provide available artists if you have them; otherwise free text for now
    var availableArtists: [String] = []

    // Callback to return a constructed ConcertVisit-like payload to the caller
    var onSave: (NewConcertVisit) -> Void

    @State private var draft = NewConcertVisit()
    @State private var showValidation = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Artist")) {
                    if availableArtists.isEmpty {
                        TextField("Artist name", text: $draft.artistName)
                            .textInputAutocapitalization(.words)
                    } else {
                        Picker("Artist", selection: $draft.artistName) {
                            ForEach(availableArtists, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                    }
                }

                Section(header: Text("Date")) {
                    DatePicker("Concert date", selection: $draft.date, displayedComponents: .date)
                }

                Section(header: Text("Details")) {
                    TextField("Title (optional)", text: $draft.title)
                        .textInputAutocapitalization(.words)
                    TextField("Venue (optional)", text: $draft.venue)
                        .textInputAutocapitalization(.words)
                    TextField("City (optional)", text: $draft.city)
                        .textInputAutocapitalization(.words)
                }

                Section(header: Text("Rating"), footer: Text("0 to 10")) {
                    Stepper(value: $draft.rating, in: 0...10) {
                        HStack {
                            Text("Rating")
                            Spacer()
                            Text("\(draft.rating)")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section(header: Text("Notes")) {
                    TextEditor(text: $draft.notes)
                        .frame(minHeight: 120)
                        .overlay(
                            Group {
                                if draft.notes.isEmpty {
                                    Text("What made it special? Favorite songs, moments, friends...")
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 8)
                                        .padding(.horizontal, 5)
                                        .allowsHitTesting(false)
                                }
                            }, alignment: .topLeading
                        )
                }

                if showValidation {
                    Section {
                        Label("Please enter at least an artist and a date.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("New Concert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        !draft.artistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        guard isValid else {
            showValidation = true
            return
        }
        onSave(draft)
        dismiss()
    }
    
    private func createVisit(from new: NewConcertVisit) async {
//        do {
//            guard let userId = SupabaseManager.shared.client.auth.currentUser?.id else { return }
//            let artistId = try await ensureArtist(named: new.artistName)
//            let dateString = ISO8601DateFormatter().string(from: new.date)
//            let payload: [String: Any] = [
//                "user_id": userId,
//                "artist_id": artistId,
//                "date": dateString,
//                "venue": new.venue.isEmpty ? NSNull() : new.venue,
//                "city": new.city.isEmpty ? NSNull() : new.city,
//                "notes": new.notes.isEmpty ? NSNull() : new.notes,
//                "rating": new.rating,
//                "title": new.title.isEmpty ? NSNull() : new.title
//            ]
//            _ = try await SupabaseManager.shared.client
//                .from("concert_visits")
//                .insert(payload)
//                .execute()
//        } catch {
//            print("failed to create visit: \(error)")
//        }
    }
}

#Preview {
    CreateConcertVisitView(availableArtists: ["Taylor Swift", "The National", "boygenius"]) { _ in }
}
