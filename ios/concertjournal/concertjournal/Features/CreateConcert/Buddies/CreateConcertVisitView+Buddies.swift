//
//  CreateConcertVisitView+Buddies.swift
//  concertjournal
//
//  Created by Paul Arbetit on 19.02.26.
//

import SwiftUI
import Supabase

// MARK: - Model

struct BuddyAttendee: Codable, Identifiable, Equatable, Hashable {

    let id: String
    let displayName: String
    let avatarURL: URL?
    let isBuddy: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case isBuddy = "is_buddy"
    }
    
    internal init(id: String, displayName: String, avatarURL: URL? = nil, isBuddy: Bool) {
        self.id = id
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.isBuddy = isBuddy
    }
    
    @MainActor @preconcurrency init(from decoder: any Decoder) throws {
        let container: KeyedDecodingContainer<BuddyAttendee.CodingKeys> = try decoder.container(keyedBy: BuddyAttendee.CodingKeys.self)
        
        self.id = try container.decode(String.self, forKey: BuddyAttendee.CodingKeys.id)
        self.displayName = try container.decode(String.self, forKey: BuddyAttendee.CodingKeys.displayName)
        self.avatarURL = try container.decodeIfPresent(URL.self, forKey: BuddyAttendee.CodingKeys.avatarURL)
        self.isBuddy = try container.decode(Bool.self, forKey: BuddyAttendee.CodingKeys.isBuddy)
        
    }
    
    @MainActor @preconcurrency func encode(to encoder: any Encoder) throws {
        var container: KeyedEncodingContainer<BuddyAttendee.CodingKeys> = encoder.container(keyedBy: BuddyAttendee.CodingKeys.self)
        
        try container.encode(self.id, forKey: BuddyAttendee.CodingKeys.id)
        try container.encode(self.displayName, forKey: BuddyAttendee.CodingKeys.displayName)
        try container.encodeIfPresent(self.avatarURL, forKey: BuddyAttendee.CodingKeys.avatarURL)
        try container.encode(self.isBuddy, forKey: BuddyAttendee.CodingKeys.isBuddy)
    }
}

// MARK: - Attendee Chip

struct AttendeeChip: View {
    let attendee: BuddyAttendee
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            // Avatar
            ZStack {
                Circle().fill(.tint.opacity(0.2))
                if let url = attendee.avatarURL {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        initialsView
                    }
                } else {
                    initialsView
                }
            }
            .frame(width: 26, height: 26)
            .clipShape(Circle())
            
            Text(attendee.displayName)
                .font(.cjBody)
                .lineLimit(1)
            
            // Buddy-Badge
            if attendee.isBuddy {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.tint)
            }
            
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(in: Capsule())
    }
    
    private var initialsView: some View {
        Text(attendee.displayName.prefix(1).uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.tint)
    }
}

// MARK: - Picker Sheet

struct BuddyAttendeePickerSheet: View {
    
    @State var selectedAttendees: [BuddyAttendee]
    @Binding var isPresented: Bool
    @Environment(\.dependencies) private var dependencies

    var onSave: ([BuddyAttendee]) -> Void

    @State private var buddies: [Buddy] = []
    @State private var isLoading = true
    @State private var customName: String = ""
    @FocusState private var customNameFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // ── Buddies ───────────────────────────────────
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.top, 32)
                        } else if !buddies.isEmpty {
                            buddiesSection()
                        }
                        
                        // ── Freie Eingabe ─────────────────────────────
                        customNameSection()
                    }
                    .padding()
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Mit dabei")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(TextKey.done.localized) {
                        onSave(selectedAttendees)
                        isPresented = false
                    }
                    .font(.cjBody.bold())
                }
            }
            .task { await loadBuddies() }
        }
        .presentationDetents([.medium, .large])
    }
    
    // MARK: - Buddies Section
    
    @ViewBuilder
    private func buddiesSection() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Concert Buddies", systemImage: "person.2.fill")
                .font(.cjHeadline)
                .padding(.leading, 4)
            
            ForEach(buddies) { buddy in
                let isSelected = selectedAttendees.contains { $0.id == buddy.userId }
                
                Button {
                    HapticManager.shared.buttonTap()
                    withAnimation(.spring(response: 0.3)) {
                        if isSelected {
                            selectedAttendees.removeAll { $0.id == buddy.userId }
                        } else {
                            selectedAttendees.append(BuddyAttendee(
                                id: buddy.userId,
                                displayName: buddy.displayName,
                                avatarURL: buddy.avatarURL,
                                isBuddy: true
                            ))
                        }
                    }
                } label: {
                    HStack(spacing: 14) {
                        // Avatar
                        ZStack {
                            Circle().fill(.tint.opacity(0.2))
                            if let url = buddy.avatarURL {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Text(buddy.displayName.prefix(1).uppercased())
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.tint)
                                }
                            } else {
                                Text(buddy.displayName.prefix(1).uppercased())
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.tint)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(buddy.displayName)
                                .font(.cjHeadline)
                                .foregroundStyle(.primary)
                            Label("\(buddy.sharedConcerts) gemeinsame Konzerte", systemImage: "music.note.list")
                                .font(.cjFootnote)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        // Checkmark
                        ZStack {
                            Circle()
                                .stroke(isSelected ? dependencies.colorThemeManager.appTint : dependencies.colorThemeManager.appTint.opacity(0.3), lineWidth: 2)
                                .frame(width: 26, height: 26)
                            if isSelected {
                                Circle()
                                    .fill(.tint)
                                    .frame(width: 26, height: 26)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .animation(.spring(response: 0.25), value: isSelected)
                    }
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? dependencies.colorThemeManager.appTint : dependencies.colorThemeManager.appTint.opacity(0.3),
                                lineWidth: isSelected ? 1.5 : 0.5
                            )
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Custom Name Section
    
    @ViewBuilder
    private func customNameSection() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Freund ohne Account", systemImage: "person.fill.questionmark")
                .font(.cjHeadline)
                .padding(.leading, 4)
            
            HStack(spacing: 10) {
                TextField("Name eingeben", text: $customName)
                    .font(.cjBody)
                    .focused($customNameFocused)
                    .submitLabel(.done)
                    .onSubmit { addCustomName() }
                
                if !customName.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button {
                        HapticManager.shared.buttonTap()
                        addCustomName()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        customNameFocused ? Color.accentColor.opacity(0.6) : Color.white.opacity(0.1),
                        lineWidth: customNameFocused ? 1.5 : 0.5
                    )
                    .animation(.easeInOut(duration: 0.2), value: customNameFocused)
            }
            
            // Bereits hinzugefügte manuelle Einträge
            let manualAttendees = selectedAttendees.filter { !$0.isBuddy }
            if !manualAttendees.isEmpty {
                VStack(spacing: 8) {
                    ForEach(manualAttendees) { attendee in
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.secondary)
                            Text(attendee.displayName)
                                .font(.cjBody)
                            Spacer()
                            Button {
                                withAnimation {
                                    selectedAttendees.removeAll { $0.id == attendee.id }
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    // MARK: - Helpers
    
    private func addCustomName() {
        let name = customName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        guard !selectedAttendees.contains(where: { $0.displayName == name && !$0.isBuddy }) else { return }
        
        withAnimation(.spring(response: 0.3)) {
            selectedAttendees.append(BuddyAttendee(
                id: UUID().uuidString,
                displayName: name,
                avatarURL: nil,
                isBuddy: false
            ))
        }
        customName = ""
        customNameFocused = false
    }
    
    private func loadBuddies() async {
        isLoading = true
        defer { isLoading = false }
        
        guard let userId = dependencies.userSessionManager.user?.id.uuidString.lowercased() else { return }
        
        do {
            let rows: [BuddyRow] = try await dependencies.supabaseClient.client
                .from("friendships")
                .select("""
                    id,
                    requester_id,
                    addressee_id,
                    status,
                    created_at,
                    requester:profiles!requester_id(id, display_name, avatar_url),
                    addressee:profiles!addressee_id(id, display_name, avatar_url),
                    shared_concerts
                """)
                .eq("status", value: "accepted")
                .or("requester_id.eq.\(userId),addressee_id.eq.\(userId)")
                .execute()
                .value
            
            buddies = rows.compactMap { row in
                let isRequester = row.requesterId == userId
                let profile = isRequester ? row.addressee : row.requester
                guard let profile else { return nil }
                return Buddy(
                    id: row.id,
                    userId: profile.id,
                    displayName: profile.displayName,
                    avatarURL: profile.avatarUrl.flatMap { URL(string: $0) },
                    sharedConcerts: row.sharedConcerts ?? 0,
                    lastActivity: row.createdAt
                )
            }
        } catch {
            print("Error loading buddies for picker: \(error)")
        }
    }
    
    // lokale Row-Models (analog zu BuddiesViewModel)
    private struct BuddyRow: Decodable {
        let id: String
        let requesterId: String
        let addresseeId: String
        let status: String
        let createdAt: Date
        let requester: ProfileRow?
        let addressee: ProfileRow?
        let sharedConcerts: Int?
        enum CodingKeys: String, CodingKey {
            case id, status, requester, addressee
            case requesterId = "requester_id"
            case addresseeId = "addressee_id"
            case createdAt = "created_at"
            case sharedConcerts = "shared_concerts"
        }
    }
    
    private struct ProfileRow: Decodable {
        let id: String
        let displayName: String
        let avatarUrl: String?
        enum CodingKeys: String, CodingKey {
            case id
            case displayName = "display_name"
            case avatarUrl = "avatar_url"
        }
    }
}
