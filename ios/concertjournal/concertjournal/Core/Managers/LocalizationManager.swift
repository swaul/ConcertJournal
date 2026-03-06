//
//  LocalizationManager.swift
//  concertjournal
//

import Foundation
import Supabase

enum LocalizationError: Error {
    case fileNotFound
    case decodingFailed
    case networkError
    case invalidResponse
}

final class LocalizationManager {
    
    var strings: [String: String] = [:]
    
    var localBackup: [String: String] = [:]
    
    private let fileManager = FileManager.default
    private let localStorageKey = "com.concertjournal.localizationVersion"
    private let localizationDir = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
    ).first?.appendingPathComponent("localizations")
    
    let supabaseClient: SupabaseClientManagerProtocol
    
    init(supabaseClient: SupabaseClientManagerProtocol) {
        self.supabaseClient = supabaseClient
        loadLocalBackup()
        loadServerStrings()
    }
    
    // MARK: - Language Resolution
    
    var currentLanguage: String = {
        let preferred = Locale.preferredLanguages.first ?? "de"
        return preferred
    }()
    
    private func resolvedLanguageFileName() -> String {
        let preferred = currentLanguage // z.B. "de-DE"
        let base = String(preferred.prefix(2)) // z.B. "de"
        
        if Bundle.main.url(forResource: preferred, withExtension: "json") != nil {
            return preferred
        } else if Bundle.main.url(forResource: base, withExtension: "json") != nil {
            return base
        }
        return "de"
    }
    
    // MARK: - Load Local Backup (aus Bundle)
    
    private func loadLocalBackup() {
        let fileName = resolvedLanguageFileName()
        guard let bundleURL = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            print("⚠️ No bundle localization found for \(fileName)")
            return
        }
        
        do {
            let data = try Data(contentsOf: bundleURL)
            let decoded = try JSONDecoder().decode([String: String].self, from: data)
            
            DispatchQueue.main.async {
                self.localBackup = decoded
                print("✅ Local backup loaded: \(decoded.count) strings")
            }
        } catch {
            print("❌ Error loading local backup: \(error)")
        }
    }
    
    private func processLocalizationStrings(_ strings: [String: String]) -> [String: String] {
        return strings.mapValues { value in
            value
                .replacingOccurrences(of: "\\n", with: "\n")
                .replacingOccurrences(of: "\\t", with: "\t")
        }
    }
    
    // MARK: - Load Server Strings
    
    private func loadServerStrings() {
        guard let localizationDir else {
            print("⚠️ Localization directory not available")
            return
        }
        
        let languageFile = localizationDir.appendingPathComponent("\(currentLanguage).json")
        
        if fileManager.fileExists(atPath: languageFile.path) {
            do {
                let data = try Data(contentsOf: languageFile)
                let decoded = try JSONDecoder().decode([String: String].self, from: data)
                let decodedAndCleaned = processLocalizationStrings(decoded)

                DispatchQueue.main.async {
                    self.strings = decodedAndCleaned
                    print("✅ Server strings loaded: \(decodedAndCleaned.count) strings")
                }
            } catch {
                print("❌ Error loading server strings: \(error)")
                strings = localBackup
            }
        } else {
            print("⚠️ No server strings file found, using local backup")
            strings = localBackup
        }
    }
    
    // MARK: - Update Localization from Supabase
    
    func checkAndUpdateLocalizationIfNeeded() async {
        do {
            let flagResponse = try await supabaseClient.client
                .from("localization_metadata")
                .select()
                .single()
                .execute()
            
            let metadata = try JSONDecoder().decode(LocalizationMetadata.self, from: flagResponse.data)
            let currentVersion = UserDefaults.standard.integer(forKey: localStorageKey)
            
            if metadata.version > currentVersion {
                print("📥 Fetching updated localization (v\(metadata.version))...")
                await fetchAndSaveLocalizationFiles(for: metadata.supportedLanguages)
                UserDefaults.standard.set(metadata.version, forKey: localStorageKey)
                
                DispatchQueue.main.async {
                    self.loadServerStrings()
                }
            }
        } catch {
            print("⚠️ Error checking localization updates: \(error)")
        }
    }
    
    private func fetchAndSaveLocalizationFiles(for languages: [String]) async {
        guard let localizationDir else { return }
        
        try? fileManager.createDirectory(at: localizationDir, withIntermediateDirectories: true)
        
        for language in languages {
            do {
                let data = try await supabaseClient.client
                    .storage
                    .from("translations")
                    .download(path: "\(language).json")
                
                let file = localizationDir.appendingPathComponent("\(language).json")
                try data.write(to: file)
                print("✅ Updated localization for \(language)")
            } catch {
                print("❌ Error fetching localization for \(language): \(error)")
            }
        }
    }
    
    // MARK: - String Access (3-Tier Fallback)
    
    /// Greift auf Strings zu mit 3-Tier Fallback:
    /// 1. Server-Version (strings)
    /// 2. Lokales Backup (localBackup)
    /// 3. Key selbst (fallback)
    func string(for key: String) -> String {
        if let serverString = strings[key], !serverString.isEmpty {
            return serverString
        }
        
        if let localString = localBackup[key], !localString.isEmpty {
            print("⚠️ Using local backup for key: \(key)")
            return localString
        }
        
        print("❌ No localization found for key: \(key)")
        return key
    }
    
    /// Greift auf Strings zu mit Formatierung (3-Tier Fallback)
    func string(for key: String, with arguments: CVarArg...) -> String {
        let template = string(for: key) // Nutzt die 3-Tier Logik
        return String(format: template, arguments: arguments)
    }
    
    // MARK: - Debug Helpers
    
    /// Zeigt den Status der Lokalisierung
    func debugStatus() {
        print("""
        🔍 Localization Status:
        - Current Language: \(currentLanguage)
        - Server Strings: \(strings.count) loaded
        - Local Backup: \(localBackup.count) loaded
        - Version: \(UserDefaults.standard.integer(forKey: localStorageKey))
        """)
    }
    
    /// Zeigt welcher String-Tier verwendet wird
    func debugStringSource(for key: String) {
        if strings[key] != nil {
            print("✅ Key '\(key)' found in SERVER strings")
        } else if localBackup[key] != nil {
            print("⚠️ Key '\(key)' found in LOCAL BACKUP (server not available)")
        } else {
            print("❌ Key '\(key)' NOT FOUND - returning key as fallback")
        }
    }
    
    // MARK: - Change Language
    
    func changeLanguage(to language: String) {
        currentLanguage = language
        loadLocalBackup()
        loadServerStrings()
        print("🌍 Language changed to: \(language)")
    }
}

// MARK: - Models

struct LocalizationMetadata: Codable {
    let version: Int
    let supportedLanguages: [String]
    let minAppVersion: String?
    let termsVersion: Int
    let termsUpdatedAtString: String?
    let privacyVersion: Int
    let privacyUpdatedAtString: String?
    
    var termsUpdatedAt: Date? {
        termsUpdatedAtString?.supabaseStringDate
    }
    
    var privacyUpdatedAt: Date? {
        privacyUpdatedAtString?.supabaseStringDate
    }
    
    enum CodingKeys: String, CodingKey {
        case version
        case supportedLanguages = "supported_languages"
        case minAppVersion = "min_app_version"
        case termsVersion = "terms_version"
        case termsUpdatedAtString = "terms_updated_at"
        case privacyVersion = "privacy_version"
        case privacyUpdatedAtString = "privacy_updated_at"
    }
}
