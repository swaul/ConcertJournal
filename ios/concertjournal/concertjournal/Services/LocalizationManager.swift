//
//  LocalizationManager.swift
//  concertjournal
//
//  Created by Paul Kühnel on 19.12.25.
//

import Foundation
import Supabase

class LocalizationManager {
    static let shared = LocalizationManager()
    
    private init() {}
    
    var texts: [String: String] = [:]
    
    func loadLocale(_ locale: String) async {
        let fileName = "\(locale).json"
        
        do {
            let result = try await SupabaseManager.shared.client.storage
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

