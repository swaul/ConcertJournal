//
//  PermissionStatusView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 10.02.26.
//

import Photos
import SwiftUI

// MARK: - Permission Status Views

struct PermissionStatusView: View {

    let status: PHAuthorizationStatus

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
        case .authorized, .limited:
            return "checkmark.circle.fill"
        case .denied, .restricted:
            return "xmark.circle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        @unknown default:
            return "questionmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch status {
        case .authorized, .limited:
            return .green
        case .denied, .restricted:
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
            return "Zugriff erlaubt"
        case .limited:
            return "Eingeschränkter Zugriff"
        case .denied:
            return "Zugriff verweigert"
        case .restricted:
            return "Zugriff eingeschränkt"
        case .notDetermined:
            return "Noch nicht entschieden"
        @unknown default:
            return "Unbekannt"
        }
    }
}
