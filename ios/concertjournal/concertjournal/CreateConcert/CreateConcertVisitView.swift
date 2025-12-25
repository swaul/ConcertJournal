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
    let artist: SpotifyArtist
    
    init(artist: SpotifyArtist) {
        self.id = UUID().uuidString
        self.artist = artist
    }
    
}

struct CreateConcertVisitView: View {
    
    @EnvironmentObject var navigationManager: NavigationManager

    @StateObject var viewModel: CreateConcertVisitViewModel
    
    @State private var draft = NewConcertVisit()
    @State private var presentConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Section(header: Text("Artist")) {
                    HStack {
                        Group {
                            if let url = viewModel.artist.firstImageURL {
                                AsyncImage(url: url) { result in
                                    result.image?
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 80)
                                }
                            } else {
                                ZStack {
                                    Rectangle()
                                        .frame(width: 80, height: 80)
                                        .background { Color.gray }
                                    Image(systemName: "note")
                                        .frame(width: 32)
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .clipShape(.circle)
                        .frame(height: 80)
                        .padding()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(viewModel.artist.name)
                                .bold()
                                .font(.system(size: 40))
                        }
                        .padding(.vertical)
                        .padding(.trailing)
                        
                        Spacer()
                    }
                }
                .glassEffect()
                
                DatePicker("Concert date", selection: $draft.date, displayedComponents: .date)
                    .padding()
                    .glassEffect()
                
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
            .padding()
        }
        .sheet(isPresented: $presentConfirmation, onDismiss: {
            navigationManager.pop()
        }, content: {
            ConfirmationView()
        })
        .navigationTitle("New Concert")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            draft.artistName = viewModel.artist.name
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { navigationManager.pop() }
                    .glassEffect()
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .glassEffect()
            }
        }
    }
    
    private func save() {
        createVisit(from: draft)
    }
    
    private func createVisit(from new: NewConcertVisit) {
        Task {
            do {
                guard let userId = SupabaseManager.shared.client.auth.currentUser?.id else { return }

                // Get-or-create artist by spotify_artist_id
                let existingArtists: [Artist] = try await SupabaseManager.shared.client
                    .from("artists")
                    .select()
                    .eq("spotify_artist_id", value: viewModel.artist.id)
                    .execute()
                    .value

                let artistId: String

                if let existing = existingArtists.first {
                    // Already exists — use database id
                    artistId = existing.id
                } else {
                    // Not found — insert a new artist and return the inserted row
                    let newArtist = Artist(
                        id: UUID().uuidString,
                        name: viewModel.artist.name,
                        imageUrl: viewModel.artist.firstImageURL?.absoluteString,
                        spotifyArtistId: viewModel.artist.id
                    )

                    _ = try await SupabaseManager.shared.client
                        .from("artists")
                        .insert(newArtist)
                        .select()
                        .single()
                        .execute()
                        .value

                    artistId = newArtist.id
                }

                let dateString = ISO8601DateFormatter().string(from: new.date)
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
                _ = try await SupabaseManager.shared.client
                    .from("concert_visits")
                    .insert(payload)
                    .execute()
                
                showConfirmation()
            } catch {
                print("failed to create visit: \(error)")
            }
        }
    }
    
    func showConfirmation() {
        presentConfirmation = true
    }
}

//#Preview {
//    CreateConcertVisitView(availableArtists: ["Taylor Swift", "The National", "boygenius"]) { _ in }
//}

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

#Preview {
    ConfirmationView()
}
