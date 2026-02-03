//
//  MockSupabaseManager.swift
//  concertjournal
//
//  Created by Paul Kühnel on 03.02.26.
//

import Foundation
import Supabase

class MockSupabaseClientManager: SupabaseClientManagerProtocol {
    
    var client: SupabaseClient {
        SupabaseClient(supabaseURL: URL(string: "https://brjekjxckpdlwffcdndn.supabase.co")!, supabaseKey: "")
    }
    var currentUser: User? {
        User.previewUser
    }
    var currentUserId: UUID? {
        User.previewUser.id
    }
    var redirectURLString = "concertjournal://auth-callback"

    func handleAuthCallback(from url: URL) async throws {

    }

}
