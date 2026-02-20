//
//  LocalizationManager.swift
//  concertjournal
//

import Foundation
import Supabase

enum LocalizationError: Error {
    case fileNotFound
    case decodingFailedcase
    case networkError
    case invalidResponse
}

final class LocalizationManager {
        
    var strings: [String: String] = [:]
    
    private let fileManager = FileManager.default
    private let localStorageKey = "com.concertjournal.localizationVersion"
    private let localizationDir = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
    ).first?.appendingPathComponent("localizations")
    
    let supabaseClient: SupabaseClientManagerProtocol
    
    init(supabaseClient: SupabaseClientManagerProtocol) {
        self.supabaseClient = supabaseClient
        loadLocalStrings()
    }
    
    // MARK: - Load Local Strings
    
    var currentLanguage: String = {
        let preferred = Locale.preferredLanguages.first ?? "de"
        return preferred
    }()
    
    private func resolvedLanguageFileName() -> String {
        let preferred = currentLanguage // z.B. "de-DE"
        let base = String(preferred.prefix(2)) // z.B. "de"
        
        // Prüfe ob de-DE.json existiert, sonst fallback auf de.json
        if Bundle.main.url(forResource: preferred, withExtension: "json") != nil {
            return preferred
        } else if Bundle.main.url(forResource: base, withExtension: "json") != nil {
            return base
        }
        return "de-DE"
    }
    
    func loadLocalStrings() {
        guard let localizationDir else { return }
        
        let languageFile = localizationDir.appendingPathComponent("\(currentLanguage).json")
        
        if fileManager.fileExists(atPath: languageFile.path) {
            do {
                let data = try Data(contentsOf: languageFile)
                let decoded = try JSONDecoder().decode([String: String].self, from: data)
                DispatchQueue.main.async {
                    self.strings = decoded
                }
            } catch {
                print("Error loading localization: \(error)")
            }
        } else {
            // Fallback: Bundle-Strings laden (für initiale Installation)
            loadBundleStrings()
        }
    }
    
    private func loadBundleStrings() {
        // Zeigt alle Dateien im Bundle
        let fileName = resolvedLanguageFileName()
        guard let bundleURL = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            print("No bundle localization found for \(fileName)")
            return
        }
        
        do {
            let data = try Data(contentsOf: bundleURL)
            let decoded = try JSONDecoder().decode([String: String].self, from: data)
            DispatchQueue.main.async {
                self.strings = decoded
            }
        } catch {
            print("Error loading bundle localization: \(error)")
        }
    }
    
    // MARK: - Update Localization from Supabase
    
    func checkAndUpdateLocalizationIfNeeded() async {
        do {
            // Feature Flag von Supabase holen
            let flagResponse = try await supabaseClient.client
                .from("localization_metadata")
                .select()
                .single()
                .execute()
            
            let metadata = try JSONDecoder().decode(LocalizationMetadata.self, from: flagResponse.data)
            let currentVersion = UserDefaults.standard.integer(forKey: localStorageKey)
            
            // Update nur wenn neuere Version vorhanden
            if metadata.version > currentVersion {
                await fetchAndSaveLocalizationFiles(for: metadata.supportedLanguages)
                UserDefaults.standard.set(metadata.version, forKey: localStorageKey)
                
                // Strings neu laden
                DispatchQueue.main.async {
                    self.loadLocalStrings()
                }
            }
        } catch {
            print("Error checking localization updates: \(error)")
        }
    }
    
    private func fetchAndSaveLocalizationFiles(for languages: [String]) async {
        guard let localizationDir else { return }
        
        // Verzeichnis erstellen falls nicht vorhanden
        try? fileManager.createDirectory(at: localizationDir, withIntermediateDirectories: true)
        
        for language in languages {
            do {
                // Von Supabase Storage herunterladen
                let data = try await supabaseClient.client
                    .storage
                    .from("translations")
                    .download(path: "\(language).json")
                
                let file = localizationDir.appendingPathComponent("\(language).json")
                try data.write(to: file)
                print("Updated localization for \(language)")
            } catch {
                print("Error fetching localization for \(language): \(error)")
            }
        }
    }
    
    // MARK: - String Access
    
    func string(for key: String) -> String {
        strings[key] ?? key // Fallback: zeige den Key selbst
    }
    
    func string(for key: String, with arguments: CVarArg...) -> String {
        let template = strings[key] ?? key
        return String(format: template, arguments: arguments)
    }
    
    // MARK: - Change Language
    
    func changeLanguage(to language: String) {
        currentLanguage = language
        loadLocalStrings()
    }
}

// MARK: - Models

struct LocalizationMetadata: Codable {
    let version: Int
    let supportedLanguages: [String]
    let minAppVersion: String?
    
    enum CodingKeys: String, CodingKey {
        case version
        case supportedLanguages = "supported_languages"
        case minAppVersion = "min_app_version"
    }
}
