//
//  SupabaseManager.swift
//  concertjournal
//
//  Created by Paul Kühnel on 19.12.25.
//

import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    let redirectURLString: String = "concertjournal://auth-callback"
    
    private init() {
        client = SupabaseClient(supabaseURL: URL(string: "https://brjekjxckpdlwffcdndn.supabase.co")!, supabaseKey: "sb_publishable_9arAE6MQR0Cj0m-jE3lXCQ_BfNy0PK7")
    }
}

