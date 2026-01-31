//
//  LocalizationManager.swift
//  concertjournal
//
//  Created by Paul Kühnel on 19.12.25.
//

import Foundation
import Supabase

class LocalizationRepository {

    private let supabaseClient: SupabaseClientManager

    init(supabaseClient: SupabaseClientManager) {
        self.supabaseClient = supabaseClient
    }
    
    var texts: [String: String] = [:]
    
    func loadLocale(_ locale: String) async {
        let fileName = "\(locale).json"
        
        do {
            let result = try await supabaseClient.client.storage
                .from("translations")
                .download(path: fileName)
            
            guard let dict = try JSONSerialization.jsonObject(with: result) as? [String: String] else { return }
            
            self.texts = dict
        } catch {
            print("Not able to load localization")
        }
    }
    
    func text(for key: String) -> String {
        texts[key] ?? NSLocalizedString(key, comment: "")
    }
}

