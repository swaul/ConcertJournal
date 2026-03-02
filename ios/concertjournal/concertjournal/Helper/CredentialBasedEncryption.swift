import Foundation
import CryptoKit
import CommonCrypto
import Supabase

class CredentialEncryption {
    
    static var shared = CredentialEncryption()
    
    var currentUserEmail: String?
    var currentUserId: String?
    var currentSession: Session?
    
    enum EncryptionError: Error, LocalizedError {
        case invalidData
        case encryptionFailed
        case decryptionFailed
        case missingKey
        
        var errorDescription: String? {
            switch self {
            case .invalidData:
                return "Invalid data format"
            case .encryptionFailed:
                return "Encryption failed"
            case .decryptionFailed:
                return "Decryption failed"
            case .missingKey:
                return "Encryption key not available"
            }
        }
    }
    
    func setCurrentSession(session: Session) {
        currentSession = session
        currentUserEmail = session.user.email
        currentUserId = session.user.id.uuidString
        logSuccess("🔐 Encryption helper ready with credentials")
    }
    
    func clearCredentials() {
        currentUserEmail = nil
        currentUserId = nil
        currentSession = nil
        logInfo("🔐 Encryption credentials cleared")
    }
    
    // MARK: - Key Generation
    
    /// Generate encryption key from Email + Session Token
    /// Diese Methode ist reproducible - gleiche Inputs = gleicher Key!
    static func generateKey(
        email: String,
        userId: String
    ) -> SymmetricKey {
        // Kombiniere Email + Token
        let combined = "\(email):\(userId)"
        guard let combinedData = combined.data(using: .utf8) else {
            fatalError("Failed to encode combined string")
        }
        
        let salt = "concertjournal-v1-salt".data(using: .utf8)!
        
        // Derive mit PBKDF2
        var derivedKey = [UInt8](repeating: 0, count: 32)
        
        let result = CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2),
            (combinedData as NSData).bytes,
            combinedData.count,
            (salt as NSData).bytes,
            salt.count,
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
            10000,
            &derivedKey,
            derivedKey.count
        )
        
        guard result == kCCSuccess else {
            fatalError("Key derivation failed")
        }
        
        let key = SymmetricKey(data: derivedKey)
        logSuccess("Generated encryption key from credentials")
        return key
    }
    
    // MARK: - Encryption
    
    static func encrypt(
        _ plaintext: String,
        with key: SymmetricKey
    ) throws -> String {
        guard let data = plaintext.data(using: .utf8) else {
            throw EncryptionError.invalidData
        }
        
        do {
            // AES.GCM.seal() gibt uns automatisch ein SealedBox mit Nonce, Ciphertext und Tag
            let sealedBox = try AES.GCM.seal(data, using: key)
            
            // Kombiniere: Nonce (12 bytes) + Ciphertext + Tag (16 bytes)
            var combined = Data()
            combined.append(contentsOf: sealedBox.nonce.withUnsafeBytes { Data($0) })
            combined.append(sealedBox.ciphertext)
            combined.append(sealedBox.tag)
            
            let encoded = combined.base64EncodedString()
            logSuccess("Encrypted data successfully")
            return encoded
        } catch {
            logError("Encryption failed", error: error)
            throw EncryptionError.encryptionFailed
        }
    }
    
    // MARK: - Decryption
    
    static func decrypt(
        _ encrypted: String,
        with key: SymmetricKey
    ) throws -> String {
        guard let data = Data(base64Encoded: encrypted) else {
            logError("Failed to decode base64")
            throw EncryptionError.invalidData
        }
        
        do {
            // Extract components:
            // Nonce: 12 bytes
            // Tag: 16 bytes
            // Ciphertext: rest
            
            let nonceSize = 12
            let tagSize = 16
            
            guard data.count >= nonceSize + tagSize else {
                logError("Data too short to contain nonce and tag")
                throw EncryptionError.invalidData
            }
            
            // Extract Nonce (first 12 bytes)
            let nonceData = data.prefix(nonceSize)
            let nonce = try AES.GCM.Nonce(data: nonceData)
            
            // Extract Tag (last 16 bytes)
            let tagData = data.suffix(tagSize)
            
            // Extract Ciphertext (everything in between)
            let ciphertextData = data.dropFirst(nonceSize).dropLast(tagSize)
            
            // Create SealedBox WITH Tag
            let sealedBox = try AES.GCM.SealedBox(
                nonce: nonce,
                ciphertext: ciphertextData,
                tag: tagData  // ← Das war das Missing!
            )
            
            // Open und dekryptiere
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            
            guard let plaintext = String(data: decryptedData, encoding: .utf8) else {
                logError("Failed to decode decrypted data as UTF-8")
                throw EncryptionError.decryptionFailed
            }
            
            logSuccess("Decrypted data successfully")
            return plaintext
        } catch is CryptoKitError {
            logError("Authentication tag verification failed - data may be corrupted or key is wrong")
            throw EncryptionError.decryptionFailed
        } catch {
            logError("Decryption failed", error: error)
            throw EncryptionError.decryptionFailed
        }
    }
}

// ========================================
// 🔧 Helper Extension für einfachere Verwendung
// ========================================

extension CredentialEncryption {
    
    /// Encrypts a string using credentials
    func encryptWithCredentials(_ plaintext: String?) throws -> String {
        guard let plaintext,
              let email = currentUserEmail,
              let userId = currentUserId else {
            throw CredentialEncryption.EncryptionError.missingKey
        }
        
        let key = CredentialEncryption.generateKey(
            email: email,
            userId: userId
        )
        
        return try CredentialEncryption.encrypt(plaintext, with: key)
    }
    
    /// Decrypts a string using credentials
    func decryptWithCredentials(_ encrypted: String) throws -> String {
        guard let email = currentUserEmail,
              let userId = currentUserId else {
            throw CredentialEncryption.EncryptionError.missingKey
        }
        
        let key = CredentialEncryption.generateKey(
            email: email,
            userId: userId
        )
        
        return try CredentialEncryption.decrypt(encrypted, with: key)
    }
}
