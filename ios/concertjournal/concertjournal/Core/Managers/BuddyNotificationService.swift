//
//  BuddyNotificationService.swift
//  concertjournal
//
//  Created by Paul Arbetit on 20.02.26.
//

import Supabase

final class BuddyNotificationService {
    
    private let supabaseClient: SupabaseClientManagerProtocol
    private let userProvider: UserSessionManagerProtocol
    
    var profile: Profile? = nil
    
    init(supabaseClient: SupabaseClientManagerProtocol, userProvider: UserSessionManagerProtocol) {
        self.supabaseClient = supabaseClient
        self.userProvider = userProvider
    }
    
    @MainActor
    func notifyBuddies(
        attendees: [BuddyAttendee],
        concertId: String,
        concertTitle: String,
    ) async {
        let buddyAttendees = attendees.filter { $0.isBuddy }
        guard !buddyAttendees.isEmpty, let currentUserName = profile?.displayName else { return }
        
        let notifications = buddyAttendees.map { attendee in
            BuddyNotificationRow(
                recipientId: attendee.id,
                type: "concert_tagged",
                title: "\(currentUserName) hat dich markiert!",
                body: "Du warst beim Konzert \"\(concertTitle)\" dabei.",
                senderAvatarUrl: profile?.avatarURL,
                concertId: concertId
            )
        }
        
        do {
            try await supabaseClient.client
                .from("notifications")
                .insert(notifications)
                .execute()
        } catch {
            print("Error sending buddy notifications: \(error)")
        }
    }
    
    private var senderName: String {
        if let profile {
            return profile.displayName ?? "Jemand"
        }
        return userProvider.user?.userMetadata["display_name"]?.stringValue ?? "Jemand"
    }
    
    private var senderAvatarUrl: String? {
        profile?.avatarURL
    }
}

// MARK: - Supabase Row

struct BuddyNotificationRow: Encodable {
    let recipientId: String
    let type: String
    let title: String
    let body: String
    let isRead: Bool = false
    let senderAvatarUrl: String?
    let concertId: String?
    
    enum CodingKeys: String, CodingKey {
        case recipientId = "recipient_id"
        case type, title, body
        case isRead = "is_read"
        case senderAvatarUrl = "sender_avatar_url"
        case concertId = "concert_id"
    }
}
