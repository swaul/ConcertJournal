//
//  AccountSettingsViewModel.swift
//  concertjournal
//
//  Created by Paul Kühnel on 02.03.26.
//

import Observation
import SwiftUI
import Supabase

enum AccountSettingsState {
    case idle
    case loading
    case success
    case error(String)
}

@Observable
final class AccountSettingsViewModel {

    // MARK: - Input

    var newEmail: String = ""

    // MARK: - Current State

    var currentEmail: String = ""

    // MARK: - UI State

    var state: AccountSettingsState = .idle

    var isValidEmail: Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: newEmail)
    }

    // MARK: - Dependencies

    private let supabaseClient: SupabaseClientManagerProtocol
    private let userProvider: UserSessionManagerProtocol
    private let photoRepository: PhotoRepositoryProtocol

    init(
        supabaseClient: SupabaseClientManagerProtocol,
        userProvider: UserSessionManagerProtocol,
        photoRepository: PhotoRepositoryProtocol
    ) {
        self.supabaseClient = supabaseClient
        self.userProvider = userProvider
        self.photoRepository = photoRepository

        // Aktuelle Email laden
        currentEmail = userProvider.user?.email ?? ""
    }

    // MARK: - Change Email

    @MainActor
    func changeEmail() async {
        guard isValidEmail else { return }
        guard newEmail != currentEmail else {
            state = .error("Neue Email ist gleich wie aktuelle Email")
            return
        }

        state = .loading

        do {
            let userAttributes = UserAttributes(data: [
                "email": .string(newEmail)
            ])
            try await supabaseClient.client.auth.update(user: userAttributes)

            // User Session refreshen
            try await userProvider.start()

            state = .success
            HapticManager.shared.buttonTap()

            // Kurz warten damit der Success-State sichtbar ist
            try await Task.sleep(for: .milliseconds(600))

            // Email zurücksetzen
            newEmail = ""
            logSuccess("Email changed successfully")
            state = .idle

        } catch {
            logError("Email change failed", error: error)
            state = .error("Email konnte nicht aktualisiert werden.")
        }
    }

    // MARK: - Delete Account

    @MainActor
    func deleteAccount() async throws {
        state = .loading

        do {
            // Account über Supabase löschen
            guard let user = userProvider.user else { return }
            try await photoRepository.deleteAllPhotos(for: user.id.uuidString.lowercased())
            try await supabaseClient.client.auth.admin.deleteUser(id: user.id)

            // Session clearen
            try await supabaseClient.client.auth.signOut()

            state = .success
            HapticManager.shared.success()

            logSuccess("Account deleted successfully")
        } catch {
            logError("Account deletion failed", error: error)
            state = .error("Account konnte nicht gelöscht werden.")
            throw error
        }
    }
}
