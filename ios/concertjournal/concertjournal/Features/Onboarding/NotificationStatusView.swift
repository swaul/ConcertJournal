//
//  NotificationStatusView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 23.02.26.
//

import Photos
import SwiftUI

// MARK: - Permission Status Views

struct NotificationStatusView: View {

    let status: UNAuthorizationStatus

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)

            Text(statusText)
                .font(.cjFootnote)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(statusColor.opacity(0.1))
        .cornerRadius(20)
    }

    private var statusIcon: String {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        @unknown default:
            return "questionmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .gray
        }
    }

    private var statusText: String {
        switch status {
        case .authorized:
            return "Benachrichtigungen erlaubt"
        case .ephemeral:
            return "Benachrichtigungen Erlaubt für limitierte zeit"
        case .denied:
            return "Benachrichtigungen verweigert"
        case .provisional:
            return "Benachrichtigungen provisorisch erlaubt"
        case .notDetermined:
            return "Noch nicht entschieden"
        @unknown default:
            return "Unbekannt"
        }
    }
}
