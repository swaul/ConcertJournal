//
//  TrackingStatusView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 10.02.26.
//

import SwiftUI
import AppTrackingTransparency

struct TrackingStatusView: View {
    let status: ATTrackingManager.AuthorizationStatus

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
        case .authorized:
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
        case .authorized:
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
            return "Tracking erlaubt"
        case .denied:
            return "Tracking verweigert"
        case .restricted:
            return "Tracking eingeschränkt"
        case .notDetermined:
            return "Noch nicht entschieden"
        @unknown default:
            return "Unbekannt"
        }
    }
}
