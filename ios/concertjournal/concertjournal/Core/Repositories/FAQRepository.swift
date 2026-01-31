//
//  FAQRepository.swift
//  concertjournal
//
//  Created by Paul Kühnel on 31.01.26.
//

import Supabase

protocol FAQRepositoryProtocol {
    func getFAQ() async throws -> [FAQ]
}

public class FAQRepository: FAQRepositoryProtocol {

    private let supabaseClient: SupabaseClientManager

    init(supabaseClient: SupabaseClientManager) {
        self.supabaseClient = supabaseClient
    }

    func getFAQ() async throws -> [FAQ] {
        let faq: [FAQ] = try await supabaseClient.client
            .from("faq_items")
            .select("id, question, answer")
            .eq("is_public", value: true)
            .order("order", ascending: true)
            .execute()
            .value

        return faq
    }
}
