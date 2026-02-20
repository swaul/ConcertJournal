//
//  iCloudKeyChainChecker.swift
//  concertjournal
//
//  Created by Paul Arbetit on 20.02.26.
//

import Foundation

enum iCloudKeychainStatus {
    case available
    case unavailable
    case unknown
}

final class iCloudKeychainChecker {
    
    static let shared = iCloudKeychainChecker()
    private let userDefaultsKey = "de.concertjournal.iCloudWarningShown"
    
    private init() {}
    
    // MARK: - Check
    
    func checkStatus() -> iCloudKeychainStatus {
        // Versuche einen Test-Eintrag mit Synchronizable zu schreiben
        let testKey = "de.concertjournal.iCloudTest"
        let testData = "test".data(using: .utf8)!
        
        let addQuery: [String: Any] = [
            kSecClass as String:              kSecClassGenericPassword,
            kSecAttrAccount as String:        testKey,
            kSecValueData as String:          testData,
            kSecAttrAccessible as String:     kSecAttrAccessibleWhenUnlocked,
            kSecAttrSynchronizable as String: true
        ]
        
        SecItemDelete(addQuery as CFDictionary)
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        SecItemDelete(addQuery as CFDictionary) // aufräumen
        
        switch status {
        case errSecSuccess:
            return .available
        case errSecNotAvailable, errSecMissingEntitlement:
            return .unavailable
        default:
            return .unknown
        }
    }
    
    // MARK: - Show Warning Once
    
    /// Gibt true zurück wenn der Hinweis angezeigt werden soll
    func shouldShowWarning() -> Bool {
        let status = checkStatus()
        let alreadyShown = UserDefaults.standard.bool(forKey: userDefaultsKey)
        
        return status == .unavailable && !alreadyShown
    }
    
    func markWarningAsShown() {
        UserDefaults.standard.set(true, forKey: userDefaultsKey)
    }
}
