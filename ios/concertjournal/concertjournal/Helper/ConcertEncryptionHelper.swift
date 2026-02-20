//
//  ConcertEncryptionHelper.swift
//  concertjournal
//

import CryptoKit
import Foundation
import Security

enum ConcertEncryptionError: Error {
    case keychainError(OSStatus)
    case encryptionFailed
    case decryptionFailed
    case invalidData
    case noActiveUser
}

final class ConcertEncryptionHelper {
    
    static let shared = ConcertEncryptionHelper()
    
    // Wird nach dem Login gesetzt
    var currentUserId: String?
    
    private init() {}
    
    // MARK: - Keychain Account per User
    
    private func keychainAccount(for userId: String) -> String {
        "de.concertjournal.encryptionKey.\(userId)"
    }
    
    // MARK: - Key Management
    
    func getOrCreateKey() throws -> SymmetricKey {
        guard let userId = currentUserId else {
            throw ConcertEncryptionError.noActiveUser
        }
        
        if let existingKey = try? loadKeyFromKeychain(for: userId) {
            return existingKey
        }
        return try createAndStoreKey(for: userId)
    }
    
    private func createAndStoreKey(for userId: String) throws -> SymmetricKey {
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        
        let query: [String: Any] = [
            kSecClass as String:              kSecClassGenericPassword,
            kSecAttrAccount as String:        keychainAccount(for: userId),
            kSecValueData as String:          keyData,
            kSecAttrAccessible as String:     kSecAttrAccessibleWhenUnlocked,
            kSecAttrSynchronizable as String: true
        ]
        
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw ConcertEncryptionError.keychainError(status)
        }
        
        return key
    }
    
    private func loadKeyFromKeychain(for userId: String) throws -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String:              kSecClassGenericPassword,
            kSecAttrAccount as String:        keychainAccount(for: userId),
            kSecReturnData as String:         true,
            kSecMatchLimit as String:         kSecMatchLimitOne,
            kSecAttrSynchronizable as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let keyData = result as? Data else {
            return nil
        }
        
        return SymmetricKey(data: keyData)
    }
    
    // MARK: - Encrypt / Decrypt
    
    func encrypt(_ string: String?) throws -> String? {
        guard let string, !string.isEmpty else { return nil }
        guard let data = string.data(using: .utf8) else {
            throw ConcertEncryptionError.invalidData
        }
        
        let key = try getOrCreateKey()
        let sealedBox = try AES.GCM.seal(data, using: key)
        
        guard let combined = sealedBox.combined else {
            throw ConcertEncryptionError.encryptionFailed
        }
        
        return combined.base64EncodedString()
    }
    
    func decrypt(_ base64String: String?) throws -> String? {
        guard let base64String, !base64String.isEmpty else { return nil }
        guard let data = Data(base64Encoded: base64String) else {
            throw ConcertEncryptionError.invalidData
        }
        
        let key = try getOrCreateKey()
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        
        guard let result = String(data: decryptedData, encoding: .utf8) else {
            throw ConcertEncryptionError.decryptionFailed
        }
        
        return result
    }
}
