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

extension View {
    @ViewBuilder
    func selectedGlass(selected: Bool) -> some View {
        if selected {
            self.glassEffect(.regular.tint(.blue.opacity(0.3)))
                .glassEffectTransition(.matchedGeometry)
        } else {
            self.glassEffect(.regular)
                .glassEffectTransition(.matchedGeometry)
        }
    }
}

class CreateConcertVisitViewModel: ObservableObject, Hashable, Equatable {
    static func == (lhs: CreateConcertVisitViewModel, rhs: CreateConcertVisitViewModel) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    let id: String
    @Published var artist: Artist?
    
    init() {
        self.id = UUID().uuidString
    }
    
}

struct CreateConcertVisitView: View {
    
    @EnvironmentObject var navigationManager: NavigationManager

    @StateObject var viewModel = CreateConcertVisitViewModel()
    
    @State private var draft = NewConcertVisit()
    @State private var presentConfirmation = false
    
    @State private var selectArtistPresenting = false
    
    var body: some View {
        Group {
            if let artist = viewModel.artist {
                ScrollView {
                    VStack(alignment: .leading) {
                        ZStack {
                            Group {
                                if let url = artist.imageUrl {
                                    AsyncImage(url: URL(string: url)) { result in
                                        result.image?
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(maxWidth: .infinity)
                                    }
                                } else {
                                    ZStack {
                                        Rectangle()
                                            .frame(maxWidth: .infinity)
                                            .background { Color.gray }
                                        Image(systemName: "note")
                                            .frame(width: 32)
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            // Fade overlay at the bottom (transparent to match background)
                            LinearGradient(
                                colors: [Color.clear, Color.clear, Color.black.opacity(0.15), Color.black.opacity(0.35), Color.black.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .allowsHitTesting(false)
                        }
                        .mask(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .black, location: 0.0),
                                    .init(color: .black, location: 0.75),
                                    .init(color: .clear, location: 1.0)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .ignoresSafeArea()
                        .frame(maxWidth: .infinity)
                        .overlay {
                            VStack(alignment: .leading, spacing: 8) {
                                Spacer()
                                Text(artist.name)
                                    .bold()
                                    .font(.system(size: 40))
                                    .padding()
                                    .glassEffect()

                            }
                            .padding(.vertical)
                            .padding(.trailing)
                        }
                        
                        DatePicker("Concert date", selection: $draft.date, displayedComponents: .date)
                            .padding()
                            .glassEffect()
                            .padding()
                        
                        TextField("Title (optional)", text: $draft.title)
                            .textInputAutocapitalization(.words)
                            .padding()
                            .glassEffect()
                        
                        TextField("Venue (optional)", text: $draft.venue)
                            .textInputAutocapitalization(.words)
                            .padding()
                            .glassEffect()
                        
                        TextField("City (optional)", text: $draft.city)
                            .textInputAutocapitalization(.words)
                            .padding()
                            .glassEffect()
                        
                        
                        Stepper(value: $draft.rating, in: 0...10) {
                            HStack {
                                Text("Rating")
                                Spacer()
                                Text("\(draft.rating)")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .glassEffect()
                        
                        TextEditor(text: $draft.notes)
                            .background { Color.clear }
                            .frame(minHeight: 120)
                            .padding()
                            .glassEffect()
                    }
                }
            } else {
                VStack(alignment: .leading) {
                    Spacer()
                    
                    Button {
                        selectArtistPresenting = true
                    } label: {
                        Text("Select Artist")
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .sheet(isPresented: $presentConfirmation, onDismiss: {
            navigationManager.pop()
        }, content: {
            ConfirmationView()
        })
        .navigationTitle("New Concert")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $selectArtistPresenting) {
            CreateConcertSelectArtistView(didSelectArtist: { artist in
                viewModel.artist = artist
                self.selectArtistPresenting = false
            })
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { navigationManager.pop() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
            }
        }
    }
    
    private func save() {
        createVisit(from: draft)
    }
    
    private func createVisit(from new: NewConcertVisit) {
        Task {
            do {
                guard let userId = SupabaseManager.shared.client.auth.currentUser?.id,
                      let artist = viewModel.artist else {
                    print("createVisit: Missing user or artist")
                    return
                }

                let existingArtistId: String?
                
                if let spotifyArtistId = artist.spotifyArtistId {
                    // Get-or-create artist by spotify_artist_id (must match your DB column type)
                    let existingArtists: [Artist] = try await SupabaseManager.shared.client
                        .from("artists")
                        .select()
                        .eq("spotify_artist_id", value: spotifyArtistId)
                        .execute()
                        .value
                    
                    existingArtistId = existingArtists.first?.id
                } else {
                    let existingArtists: [Artist] = try await SupabaseManager.shared.client
                        .from("artists")
                        .select()
                        .eq("name", value: artist.name)
                        .execute()
                        .value
                    
                    existingArtistId = existingArtists.first?.id
                }
                
                let artistId: String

                if let existingArtistId {
                    artistId = existingArtistId
                } else {
                    // Insert artist and prefer returning the inserted row to get canonical id
                    let artistData = artist.toData()
                    let inserted: Artist = try await SupabaseManager.shared.client
                        .from("artists")
                        .insert(artistData)
                        .select()
                        .single()
                        .execute()
                        .value
                    
                    artistId = inserted.id
                }

                // Format date as ISO8601 with fractional seconds in UTC (commonly accepted by Postgres timestamptz)
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                let dateString = formatter.string(from: new.date)

                // NOTE: If your `user_id` column is a UUID type, sending a string is typically fine,
                // but if you have issues, consider mapping to `.string` vs `.uuid` depending on your AnyJSON support.
                let payload: [String: AnyJSON] = [
                    "user_id": .string(userId.uuidString),
                    "artist_id": .string(artistId),
                    "date": .string(dateString),
                    "venue": new.venue.isEmpty ? .null : .string(new.venue),
                    "city": new.city.isEmpty ? .null : .string(new.city),
                    "notes": new.notes.isEmpty ? .null : .string(new.notes),
                    "rating": .integer(new.rating),
                    "title": new.title.isEmpty ? .null : .string(new.title)
                ]

                // Insert visit and log returned value for debugging
                let response = try await SupabaseManager.shared.client
                    .from("concert_visits")
                    .insert(payload)
                    .select()
                    .single()
                    .execute()

                // Optional: print the inserted visit for verification
                #if DEBUG
                do {
                    let data = try JSONSerialization.data(withJSONObject: response.data, options: [.prettyPrinted])
                    if let json = String(data: data, encoding: .utf8) {
                        print("Inserted concert_visits row:\n\(json)")
                    }
                } catch {
                    print("Debug print of inserted row failed: \(error)")
                }
                #endif

                showConfirmation()
            } catch {
                // Try to surface as much info as possible from Supabase errors
                print("failed to create visit: \(error)")
            }
        }
    }

    func showConfirmation() {
        presentConfirmation = true
    }
}

#Preview {
    CreateConcertVisitView()
}

struct ConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var drawProgress: CGFloat = 0
    @State private var showDone: Bool = false
    
    var body: some View {
        VStack(spacing: 16) {
            CheckmarkShape()
                .trim(from: 0, to: drawProgress)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                .frame(width: 64, height: 64)
                .contentTransition(.interpolate)
            
            Text("Done")
                .font(.headline)
                .opacity(showDone ? 1 : 0)
                .animation(.easeIn(duration: 0.25), value: showDone)
        }
        .padding(24)
        .onAppear {
            // Animate the checkmark stroke
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.1)) {
                drawProgress = 1
            }
            // Fade in the label slightly after the stroke completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                showDone = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                dismiss()
            }
        }
        .presentationDetents([.height(180)]) // Small sheet height
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
    }
}

struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // A proportional checkmark path
        let w = rect.width
        let h = rect.height
        
        let start = CGPoint(x: 0.2 * w, y: 0.55 * h)
        let mid = CGPoint(x: 0.45 * w, y: 0.8 * h)
        let end = CGPoint(x: 0.8 * w, y: 0.25 * h)
        
        path.move(to: start)
        path.addLine(to: mid)
        path.addLine(to: end)
        return path
    }
}

