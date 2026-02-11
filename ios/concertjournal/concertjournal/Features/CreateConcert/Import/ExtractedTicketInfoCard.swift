//
//  ExtractedTicketInfoCard.swift
//  concertjournal
//
//  Created by Paul Kühnel on 11.02.26.
//

import SwiftUI

struct ExtractedTicketInfoCard: View {
    let info: TicketInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Erkannte Informationen")
                .font(.cjCaption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(icon: "music.mic", title: "Künstler", value: info.artistName)
                
                if let venue = info.venueName {
                    InfoRow(icon: "building.2", title: "Location", value: venue)
                }
                
                if let city = info.city {
                    InfoRow(icon: "location.fill", title: "Stadt", value: city)
                }
                
                if let date = info.date {
                    InfoRow(icon: "calendar", title: "Datum", value: date.formatted(date: .long, time: .shortened))
                }
                
                if let price = info.price {
                    InfoRow(icon: "eurosign", title: "Preis", value: price)
                }
                
                if let seat = info.seatInfo {
                    InfoRow(icon: "ticket", title: "Sitzplatz", value: seat)
                }
                
                if let provider = info.ticketProvider {
                    InfoRow(icon: "building.columns", title: "Anbieter", value: provider)
                }
            }
        }
        .padding()
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.cjCaption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.cjBody)
            }
        }
    }
}
