//
//  HTMLLoader.swift
//  concertjournal
//
//  Created by Paul Arbetit on 06.03.26.
//

import Foundation
import Supabase

// MARK: - HTML Document Loader

enum HTMLDocumentType: Equatable, Sendable {
    case termsOfService(version: Int)
    case privacyPolicy(version: Int)
    
    var storagePath: String {
        switch self {
        case .termsOfService(let version):
            return "legal/terms-v\(version).html"
        case .privacyPolicy(let version):
            return "legal/privacy-v\(version).html"
        }
    }
    
    var bundleFileName: String {
        switch self {
        case .termsOfService:
            return "terms"  // terms.html im Bundle
        case .privacyPolicy:
            return "privacy"  // privacy.html im Bundle
        }
    }
}

actor HTMLDocumentLoader {
    
    private let supabaseClient: SupabaseClientManagerProtocol
    
    init(supabaseClient: SupabaseClientManagerProtocol) {
        self.supabaseClient = supabaseClient
    }
    
    // MARK: - Load Document (Supabase → Fallback Bundle)
    
    func loadDocument(_ type: HTMLDocumentType) async -> String {
        // Tier 1: Supabase Storage
        if let content = await loadFromSupabase(type) {
            print("✅ Loaded \(type) from Supabase")
            return content
        }
        
        // Tier 2: Bundle Fallback
        if let content = await loadFromBundle(type) {
            print("⚠️ Loaded \(type) from Bundle (fallback)")
            return content
        }
        
        // Tier 3: Error HTML
        print("❌ Failed to load \(type)")
        return await errorHTML(for: type)
    }
    
    // MARK: - Private: Load from Supabase
    
    private func loadFromSupabase(_ type: HTMLDocumentType) async -> String? {
        do {
            let data = try await supabaseClient.client
                .storage
                .from("documents")
                .download(path: type.storagePath)
            
            let content = String(data: data, encoding: .utf8)
            return content
        } catch {
            print("⚠️ Error loading from Supabase: \(error)")
            return nil
        }
    }
    
    // MARK: - Private: Load from Bundle
    
    @MainActor
    private func loadFromBundle(_ type: HTMLDocumentType) -> String? {
        guard let bundleURL = Bundle.main.url(
            forResource: type.bundleFileName,
            withExtension: "html"
        ) else {
            return nil
        }
        
        do {
            let content = try String(contentsOf: bundleURL, encoding: .utf8)
            return content
        } catch {
            print("❌ Error loading from Bundle: \(error)")
            return nil
        }
    }
    
    // MARK: - Error HTML
    
    @MainActor
    private func errorHTML(for type: HTMLDocumentType) -> String {
        let title = type == .termsOfService(version: 0) ? "Terms of Service" : "Privacy Policy"
        
        return """
        <!DOCTYPE html>
        <html lang="de">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    background: #0f0f14;
                    color: #ffffff;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    min-height: 100vh;
                    margin: 0;
                    padding: 20px;
                }
                .container {
                    text-align: center;
                    max-width: 500px;
                }
                h1 {
                    font-size: 24px;
                    margin: 0 0 10px 0;
                }
                p {
                    opacity: 0.7;
                    margin: 0;
                    line-height: 1.6;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>⚠️ Document Not Available</h1>
                <p>Sorry, we couldn't load the \(title). Please try again later.</p>
            </div>
        </body>
        </html>
        """
    }
}
