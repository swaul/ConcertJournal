//
//  BuddyQuickAddShee.swift
//  concertjournal
//
//  Created by Paul Arbetit on 19.02.26.
//

import SwiftUI
import Foundation
import Supabase

struct BuddyQuickAddSheet: View {
    let code: BuddyCode
    @Environment(\.dependencies) var dependencies
    @Environment(\.dismiss) private var dismiss
    
    @State private var result: UserSearchResult? = nil
    @State private var state: QuickAddState = .loading
    
    enum QuickAddState { case loading, found, notFound, sent, error }
    
    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Griff
                Capsule()
                    .fill(.secondary.opacity(0.3))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                
                Spacer()
                
                switch state {
                case .loading:
                    ProgressView()
                    Text(TextKey.buddiesSearchUser.localized)
                        .font(.cjBody).foregroundStyle(.secondary)
                    
                case .found:
                    if let result {
                        foundView(result: result)
                    }
                    
                case .notFound:
                    Image(systemName: "person.fill.questionmark")
                        .font(.system(size: 52)).foregroundStyle(.secondary)
                    // TODO: LOCALIZATION
                    Text(TextKey.buddiesUserNotFound.localized)
                    Text("Kein Nutzer gefunden")
                        .font(.cjTitle2).fontWeight(.semibold)
                    Text(TextKey.buddiesCodeNotFound.localized(with: code.code))
                        .font(.cjBody).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal, 32)
                    
                case .sent:
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 52)).foregroundStyle(.tint)
                    Text(TextKey.buddiesRequestSent.localized)
                        .font(.cjTitle2).fontWeight(.semibold)
                    Text(TextKey.buddiesAfterAccept.localized(with: result?.displayName "der Nutzer"))
                        .font(.cjBody).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal, 32)
                    
                case .error:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 52)).foregroundStyle(.orange)
                    Text(TextKey.errorSomethingWrong.localized)
                        .font(.cjBody).foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Dismiss
                Button(TextKey.close.localized) { dismiss() }
                    .font(.cjBody).foregroundStyle(.secondary)
                    .padding(.bottom, 32)
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden) // eigener Griff oben
        .task { await loadUser() }
    }
    
    @ViewBuilder
    private func foundView(result: UserSearchResult) -> some View {
        VStack(spacing: 20) {
            // Avatar
            AvatarView(url: result.avatarURL, name: result.displayName, size: 80)
            
            VStack(spacing: 6) {
                Text(result.displayName)
                    .font(.custom("PlayfairDisplay-Bold", size: 28))
                if let code = result.buddyCode {
                    Text(code)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            
            // Status
            switch result.relationStatus {
            case .none:
                Button {
                    Task { await sendRequest(to: result.id) }
                } label: {
                    Label(TextKey.sendFriendRequest.localized, systemImage: "person.badge.plus")
                        .font(.cjBody).fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)
                .padding(.horizontal, 32)
                
            case .pending:
                Label(TextKey.requestAlreadySent.localized, systemImage: "clock")
                    .font(.cjBody).foregroundStyle(.secondary)
                
            case .alreadyFriends:
                Label(TextKey.alreadyBuddies.localized, systemImage: "checkmark.circle.fill")
                    .font(.cjBody).foregroundStyle(.green)
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadUser() async {
        // Supabase-Abfrage direkt hier – kein ViewModel nötig da einmaliger Load
        do {
            let rows: [ProfileRow] = try await dependencies.supabaseClient.client
                .from("profiles")
                .select("id, display_name, avatar_url, buddy_code")
                .eq("buddy_code", value: code.code.uppercased())
                .limit(1)
                .execute()
                .value
            
            if let profile = rows.first {
                // Checken ob bereits befreundet
                let currentUserId = dependencies.userSessionManager.user?.id.uuidString ?? ""
                let friendships: [FriendshipRow] = try await dependencies.supabaseClient.client
                    .from("friendships")
                    .select("status")
                    .or("requester_id.eq.\(currentUserId),addressee_id.eq.\(currentUserId)")
                    .or("requester_id.eq.\(profile.id),addressee_id.eq.\(profile.id)")
                    .limit(1)
                    .execute()
                    .value
                
                let relationStatus: UserSearchResult.RelationStatus = {
                    guard let friendship = friendships.first else { return .none }
                    return friendship.status == "accepted" ? .alreadyFriends : .pending
                }()
                
                result = UserSearchResult(
                    id: profile.id,
                    displayName: profile.displayName,
                    avatarURL: profile.avatarUrl.flatMap { URL(string: $0) },
                    buddyCode: profile.buddyCode,
                    relationStatus: relationStatus
                )
                withAnimation { state = .found }
            } else {
                withAnimation { state = .notFound }
            }
        } catch {
            withAnimation { state = .error }
        }
    }
    
    private func sendRequest(to userId: String) async {
        guard let currentUserId = dependencies.userSessionManager.user?.id.uuidString else { return }
        do {
            try await dependencies.supabaseClient.client
                .from("friendships")
                .insert(["requester_id": currentUserId, "addressee_id": userId, "status": "pending"])
                .execute()
            HapticManager.shared.buttonTap()
            withAnimation { state = .sent }
            // Sheet nach kurzer Pause automatisch schließen
            try? await Task.sleep(for: .seconds(2))
            dismiss()
        } catch {
            withAnimation { state = .error }
        }
    }
    
    // lokale Row-Models
    private struct ProfileRow: Decodable {
        let id: String
        let displayName: String
        let avatarUrl: String?
        let buddyCode: String?
        enum CodingKeys: String, CodingKey {
            case id
            case displayName = "display_name"
            case avatarUrl = "avatar_url"
            case buddyCode = "buddy_code"
        }
    }
    
    private struct FriendshipRow: Decodable {
        let status: String
    }
}
