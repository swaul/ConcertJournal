//
//  TermsViews.swift
//  concertjournal
//
//  Created by Paul Arbetit on 06.03.26.
//

import SwiftUI
import WebKit
import Supabase

// MARK: - Terms of Service View

struct HTMLTermsView: View {
    @Environment(\.dependencies) var dependencies
    
    @State private var htmlContent = ""
    @State private var isLoading = true
    @State private var loadError: Error?
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    VStack(spacing: 12) {
                        FlowerLoading()
                        Text(TextKey.legalTosLoading.localized)
                            .font(.cjBody)
                            .foregroundStyle(.secondary)
                    }
                } else if htmlContent.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.orange)
                        Text(TextKey.legalTosLoadingFailed.localized)
                            .font(.cjBody)
                        Button(TextKey.genericRetry.localized) {
                            Task {
                                await loadTerms()
                            }
                        }
                        .buttonStyle(.glassProminent)
                    }
                } else {
                    TermsRepresentable(htmlContent: htmlContent)
                        .ignoresSafeArea()
                }
            }
            .navigationTitle(TextKey.legalTosTitle.localized)
        }
        .task {
            await loadTerms()
        }
    }
    
    private func loadTerms() async {
        isLoading = true
        
        let loader = HTMLDocumentLoader(
            supabaseClient: dependencies.supabaseClient
        )
        
        // Hole aktuelle Version von Metadata
        do {
            let response = try await dependencies.supabaseClient.client
                .from("localization_metadata")
                .select()
                .single()
                .execute()
            
            let metadata = try JSONDecoder().decode(LocalizationMetadata.self, from: response.data)
            
            // Lade die richtige Version
            htmlContent = await loader.loadDocument(.termsOfService(version: metadata.termsVersion))
            isLoading = false
            
            print("✅ Loaded Terms v\(metadata.termsVersion)")
        } catch {
            print("❌ Error loading terms: \(error)")
            // Fallback: Lade Default-Version
            htmlContent = await loader.loadDocument(.termsOfService(version: 1))
            isLoading = false
        }
    }
}

// MARK: - Privacy Policy View

struct HTMLPrivacyView: View {
    @Environment(\.dependencies) var dependencies
    
    @State private var htmlContent = ""
    @State private var isLoading = true
    @State private var loadError: Error?
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    VStack(spacing: 12) {
                        FlowerLoading()
                        Text(TextKey.legalPrivacyLoading.localized)
                            .font(.cjBody)
                            .foregroundStyle(.secondary)
                    }
                } else if htmlContent.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.orange)
                        Text(TextKey.legalPrivacyLoadingFailed.localized)
                            .font(.cjBody)
                        Button(TextKey.genericRetry.localized) {
                            Task {
                                await loadPrivacy()
                            }
                        }
                        .buttonStyle(.glassProminent)
                    }
                } else {
                    PrivacyRepresentable(htmlContent: htmlContent)
                        .ignoresSafeArea()
                }
            }
            .navigationTitle(TextKey.legalPrivacyTitle.localized)
        }
        .task {
            await loadPrivacy()
        }
    }
    
    private func loadPrivacy() async {
        isLoading = true
        
        let loader = HTMLDocumentLoader(
            supabaseClient: dependencies.supabaseClient
        )
        
        // Hole aktuelle Version von Metadata
        do {
            let response = try await dependencies.supabaseClient.client
                .from("localization_metadata")
                .select()
                .single()
                .execute()
            
            let metadata = try JSONDecoder().decode(LocalizationMetadata.self, from: response.data)
            
            // Lade die richtige Version
            htmlContent = await loader.loadDocument(.privacyPolicy(version: metadata.privacyVersion))
            isLoading = false
            
            print("✅ Loaded Privacy v\(metadata.privacyVersion)")
        } catch {
            print("❌ Error loading privacy: \(error)")
            // Fallback: Lade Default-Version
            htmlContent = await loader.loadDocument(.privacyPolicy(version: 1))
            isLoading = false
        }
    }
}

// MARK: - UIViewRepresentable für Terms

struct TermsRepresentable: UIViewRepresentable {
    let htmlContent: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        
        // Lade HTML-Content
        webView.loadHTMLString(htmlContent, baseURL: nil)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {}
}

// MARK: - UIViewRepresentable für Privacy

struct PrivacyRepresentable: UIViewRepresentable {
    let htmlContent: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        
        // Lade HTML-Content
        webView.loadHTMLString(htmlContent, baseURL: nil)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {}
}
