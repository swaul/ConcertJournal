//
//  UserSetupViewModel.swift
//  concertjournal
//
//  Created by Paul Arbetit on 19.02.26.
//

import Observation
import PhotosUI
import Supabase
import SwiftUI

enum UserSetupState {
    case idle
    case loading
    case success
    case error(String)
}

@Observable
final class UserSetupViewModel {
    
    // MARK: - Input
    
    var displayName: String
    var selectedPhotoItem: PhotosPickerItem? = nil
    var selectedImage: UIImage? = nil
    
    // MARK: - State
    
    var state: UserSetupState = .idle
    var isUploadingAvatar = false
    
    var canProceed: Bool {
        displayName.trimmingCharacters(in: .whitespaces).count >= 2
    }
    
    // MARK: - Dependencies
    
    private let supabaseClient: SupabaseClientManagerProtocol
    private let userProvider: UserSessionManagerProtocol
    let onComplete: () -> Void
    
    init(
        supabaseClient: SupabaseClientManagerProtocol,
        userProvider: UserSessionManagerProtocol,
        onComplete: @escaping () -> Void
    ) {
        self.supabaseClient = supabaseClient
        self.userProvider = userProvider
        self.onComplete = onComplete
        
        let existingName = userProvider.user?.userMetadata["display_name"]?.stringValue ?? ""
        if !existingName.isEmpty {
            displayName = existingName
        } else {
            displayName = ""
        }
    }
    
    // MARK: - Photo laden
    
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
            state = .error("Foto konnte nicht geladen werden.")
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
            // 1. Avatar hochladen falls vorhanden
            var avatarURL: String? = nil
            if let image = selectedImage {
                avatarURL = try await uploadAvatar(image: image, userId: userId)
            }
            
            // 2. Auth Metadata updaten (display_name)
            let userAttributes = UserAttributes(data: [
                "display_name": .string(name),
                "setup_completed": .bool(true)
            ])
            try await supabaseClient.client.auth.update(user: userAttributes)
            
            // 3. Profiles-Tabelle updaten
            var profileUpdate: [String: AnyJSON] = ["display_name": .string(name)]
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
            logSuccess("Profile saving successful")
            onComplete()
            
        } catch {
            logError("Profile saving failed", error: error)
            state = .error("Profil konnte nicht gespeichert werden.")
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
