//
//  BuddyNotificationService.swift
//  concertjournal
//
//  Created by Paul Arbetit on 20.02.26.
//

import Supabase

final class BuddyNotificationService {
    
    private let supabaseClient: SupabaseClientManagerProtocol
    
    var currentUserName: String? = nil
    
    init(supabaseClient: SupabaseClientManagerProtocol) {
        self.supabaseClient = supabaseClient
    }
    
    @MainActor
    func notifyBuddies(
        attendees: [BuddyAttendee],
        concertId: String,
        concertTitle: String,
    ) async {
        let buddyAttendees = attendees.filter { $0.isBuddy }
        guard !buddyAttendees.isEmpty, let currentUserName else { return }
        
        let notifications = buddyAttendees.map { attendee in
            ConcertNotificationRow(
                recipientId: attendee.id,
                type: "concert_tagged",
                title: "\(currentUserName) hat dich markiert!",
                body: "Du warst beim Konzert \"\(concertTitle)\" dabei.",
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
}

// MARK: - Supabase Row

private struct ConcertNotificationRow: Encodable {
    let recipientId: String
    let type: String
    let title: String
    let body: String
    let concertId: String
    let isRead: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case recipientId = "recipient_id"
        case type, title, body
        case concertId = "concert_id"
        case isRead = "is_read"
    }
}
