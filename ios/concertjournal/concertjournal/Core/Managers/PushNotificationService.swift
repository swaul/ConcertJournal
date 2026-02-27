//
//  PushNotificationService.swift
//  concertjournal
//
//  Created by Paul Kühnel on 23.02.26.
//

import UIKit
import Supabase

protocol PushNotificationManagerProtocol {
    func storeDeviceToken(_ tokenData: Data) async
    func registerCachedTokenIfNeeded() async
    func removeDeviceToken() async
}

final class PushNotificationManager: PushNotificationManagerProtocol {

    private let supabaseClient: SupabaseClientManagerProtocol

    init(supabaseClient: SupabaseClientManagerProtocol) {
        self.supabaseClient = supabaseClient
    }

    func storeDeviceToken(_ tokenData: Data) async {
        let token = tokenData.map { String(format: "%02x", $0) }.joined()

        // Token cachen für spätere Re-Registrierung nach Login
        UserDefaults.standard.set(token, forKey: "lastDeviceToken")

        guard let userId = supabaseClient.currentUserId else {
            return
        }

        await upsertToken(token, for: userId)
    }

    func registerCachedTokenIfNeeded() async {
        guard let token = UserDefaults.standard.string(forKey: "lastDeviceToken"),
              let userId = supabaseClient.currentUserId else { return }
        await upsertToken(token, for: userId)
    }

    private func upsertToken(_ token: String, for userId: UUID) async {
        let row = DeviceTokenRow(userId: userId, token: token, environment: DeviceTokenRow.currentEnvironment)
        do {
            try await supabaseClient.client
                .from("device_tokens")
                .upsert(row, onConflict: "user_id, token")
                .execute()
            logSuccess("Device token stored", category: .auth)
        } catch {
            logError("Failed to store device token", error: error, category: .auth)
        }
    }

    func removeDeviceToken() async {
        // Beim Logout Token löschen, damit kein Push an abgemeldetes Gerät geht
        guard let userId = supabaseClient.currentUserId else { return }

        do {
            try await supabaseClient.client
                .from("device_tokens")
                .delete()
                .eq("user_id", value: userId)
                .execute()
        } catch {
            logError("Failed to remove device token", error: error, category: .auth)
        }
    }
}

// MARK: - Supabase Row

private struct DeviceTokenRow: Encodable {
    let userId: UUID
    let token: String
    let platform: String = "ios"
    let environment: String
    
    static var currentEnvironment: String {
#if DEBUG
        return "development"
#else
        return "production"
#endif
    }
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case token, platform, environment
    }
}
