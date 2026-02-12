//
//  ExtractedTicketInfoCard.swift
//  concertjournal
//
//  Created by Paul Kühnel on 11.02.26.
//

import SwiftUI

struct ExtractedTicketInfoCard: View {

    @State var artistName: String
    @State var venueName: String
    @State var city: String
    @State var dateString: String
    @State var price: String
    @State var seatInfo: String
    @State var ticketProvider: String

    let extractedText: String

    var onSubmit: (TicketInfo) -> Void

    init(info: TicketInfo, extractedText: String, onSubmit: @escaping (TicketInfo) -> Void ) {
        self.artistName = info.artistName
        self.venueName = info.venueName ?? ""
        self.city = info.city ?? ""
        self.dateString = info.date?.formatted() ?? ""
        self.price = info.price ?? ""
        self.seatInfo = info.seatInfo ?? ""
        self.ticketProvider = info.ticketProvider ?? ""

        self.extractedText = extractedText

        self.onSubmit = onSubmit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Erkannte Informationen")
                .font(.cjCaption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(icon: "music.mic", title: "Künstler", value: $artistName, extractedText: extractedText)

                if !venueName.isEmpty {
                    InfoRow(icon: "building.2", title: "Location", value: $venueName, extractedText: extractedText)
                }
                
                if !city.isEmpty {
                    InfoRow(icon: "location.fill", title: "Stadt", value: $city, extractedText: extractedText)
                }
                
                if !dateString.isEmpty {
                    InfoRow(icon: "calendar", title: "Datum", value: $dateString, extractedText: extractedText)
                }
                
                if !price.isEmpty {
                    InfoRow(icon: "eurosign", title: "Preis", value: $price, extractedText: extractedText)
                }
                
                if !seatInfo.isEmpty {
                    InfoRow(icon: "ticket", title: "Ticket art", value: $seatInfo, extractedText: extractedText)
                }
                
                if !ticketProvider.isEmpty {
                    InfoRow(icon: "building.columns", title: "Anbieter", value: $ticketProvider, extractedText: extractedText)
                }
            }

            Button {
                confirmInfo()
            } label: {
                Text("Konzert erstellen")
                    .font(.cjHeadline)
                    .frame(maxWidth: .infinity)
                    .padding(4)
            }
            .buttonStyle(.glassProminent)
            .padding(.horizontal)
        }
        .padding()
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    func confirmInfo() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-YYYY"

        let ticketInfo = TicketInfo(artistName: artistName, venueName: venueName, city: city, date: dateFormatter.date(from: dateString), price: price, seatInfo: seatInfo, ticketProvider: ticketProvider)

        onSubmit(ticketInfo)
    }
}

struct InfoRow: View {

    @Environment(\.dependencies) var dependencies

    let icon: String
    let title: String
    @Binding var value: String
    let extractedText: String

    var extractedTextElements: [String] {
        extractedText.components(separatedBy: "\n")
                     .sorted(by: { $0.count < $1.count })
                     .map { $0.trimmingCharacters(in: .whitespaces) }
                     .filter { !$0.isEmpty }
    }

    @FocusState var focused: Bool

    @State var focusedAnimated: Bool = false

    var body: some View {
        VStack {
            if focusedAnimated {
                Text("Da hat wohl etwas nicht geklappt..")
                    .font(.cjFootnote)
                Text("Vielleicht ist hier etwas dabei:")
                    .font(.cjCaption)
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(extractedTextElements, id: \.self) { element in
                            Button {
                                value = element
                            } label: {
                                Text(element)
                                    .font(.cjBody)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .contentShape(Capsule())
                            .background(
                                Capsule()
                                    .fill(Color(uiColor: .systemBackground))
                            )
                            .background(
                                Capsule()
                                    .fill(dependencies.colorThemeManager.appTint)
                            )
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .frame(height: 30)
            }
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.cjCaption)
                        .foregroundColor(.secondary)
                    TextField(title, text: $value)
                        .font(.cjBody)
                        .focused($focused)
                        .onChange(of: focused) { _, newValue in
                            withAnimation {
                                focusedAnimated = newValue
                            }
                        }
                }
            }
        }
    }
}
