//
//  EditProfileViewModel.swift
//  concertjournal
//
//  Created by Paul Arbetit on 01.03.26.
//

import Observation
import PhotosUI
import Supabase
import SwiftUI

enum EditProfileState {
    case idle
    case loading
    case success
    case error(String)
}

@Observable
final class EditProfileViewModel {
    
    // MARK: - Input
    
    var displayName: String = ""
    var selectedPhotoItem: PhotosPickerItem? = nil
    var selectedImage: UIImage? = nil
    
    // MARK: - Current State
    
    var currentImage: UIImage? = nil
    var currentDisplayName: String = ""
    
    // MARK: - UI State
    
    var state: EditProfileState = .idle
    var isUploadingAvatar = false
    
    var canProceed: Bool {
        displayName.trimmingCharacters(in: .whitespaces).count >= 2
    }
    
    var hasChanges: Bool {
        let trimmedName = displayName.trimmingCharacters(in: .whitespaces)
        let trimmedCurrent = currentDisplayName.trimmingCharacters(in: .whitespaces)
        return selectedImage != nil || trimmedName != trimmedCurrent
    }
    
    // MARK: - Dependencies
    
    private let supabaseClient: SupabaseClientManagerProtocol
    private let userProvider: UserSessionManagerProtocol
    
    init(
        supabaseClient: SupabaseClientManagerProtocol,
        userProvider: UserSessionManagerProtocol
    ) {
        self.supabaseClient = supabaseClient
        self.userProvider = userProvider
        
        // Aktuellen Namen laden
        let existingName = userProvider.user?.userMetadata["display_name"]?.stringValue ?? ""
        currentDisplayName = existingName
        displayName = existingName
        
        // Avatar URL laden (falls vorhanden)
        Task {
            await loadCurrentAvatar()
        }
    }
    
    // MARK: - Avatar laden
    
    @MainActor
    private func loadCurrentAvatar() async {
        guard let userId = userProvider.user?.id.uuidString.lowercased() else { return }
        
        do {
            let path = "\(userId)/avatar.jpg"
            let data = try await supabaseClient.client.storage
                .from("avatars")
                .download(path: path)
            
            if let image = UIImage(data: data) {
                currentImage = image
            }
        } catch {
            // Avatar existiert möglicherweise noch nicht - kein Fehler
            logDebug("No current avatar found")
        }
    }
    
    @MainActor
    func loadSelectedPhoto() async {
        guard let item = selectedPhotoItem else { return }
        isUploadingAvatar = true
        defer { isUploadingAvatar = false }
        
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                // Komprimieren & auf max. 512px skalieren
                selectedImage = image.resized(to: CGSize(width: 512, height: 512))
            }
        } catch {
            state = .error(TextKey.profileEditPhotoLoadingFailed.localized)
        }
    }
    
    // MARK: - Speichern
    
    @MainActor
    func save() async {
        let name = displayName.trimmingCharacters(in: .whitespaces)
        guard name.count >= 2 else { return }
        guard let userId = userProvider.user?.id.uuidString.lowercased() else { return }
        
        state = .loading
        
        do {
            // 1. Avatar hochladen falls neues Bild ausgewählt
            var avatarURL: String? = nil
            if let image = selectedImage {
                avatarURL = try await uploadAvatar(image: image, userId: userId)
            }
            
            // 2. Auth Metadata updaten (display_name)
            let userAttributes = UserAttributes(data: [
                "display_name": .string(name)
            ])
            try await supabaseClient.client.auth.update(user: userAttributes)
            
            // 3. Profiles-Tabelle updaten
            var profileUpdate: [String: AnyJSON] = [
                "id": .string(userId),
                "display_name": .string(name),
                "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
            ]
            
            if let url = avatarURL {
                profileUpdate["avatar_url"] = .string(url)
            }
            
            try await supabaseClient.client
                .from("profiles")
                .upsert(profileUpdate)
                .execute()
            
            // 4. User-Session refreshen
            try await userProvider.start()
            
            state = .success
            HapticManager.shared.buttonTap()
            
            // Kurz warten damit der Success-State sichtbar ist
            try await Task.sleep(for: .milliseconds(600))
            logSuccess("Profile update successful")
            
        } catch {
            logError("Profile update failed", error: error)
            state = .error(TextKey.profileEditProfileSaveFailed.localized)
        }
    }
    
    // MARK: - Avatar Upload
    
    private func uploadAvatar(image: UIImage, userId: String) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw UploadError.compressionFailed
        }
        
        let path = "\(userId)/avatar.jpg"
        
        try await supabaseClient.client.storage
            .from("avatars")
            .upload(path, data: data, options: FileOptions(
                cacheControl: "3600",
                contentType: "image/jpeg",
                upsert: true
            ))
        
        let response = try supabaseClient.client.storage
            .from("avatars")
            .getPublicURL(path: path)
        
        return response.absoluteString
    }
    
    enum UploadError: Error {
        case compressionFailed
    }
}

// MARK: - UIImage Helper

private extension UIImage {
    func resized(to targetSize: CGSize) -> UIImage {
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let scale = min(widthRatio, heightRatio)
        guard scale < 1 else { return self } // Nicht hochskalieren
        
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
