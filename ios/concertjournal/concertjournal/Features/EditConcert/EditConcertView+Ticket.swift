//
//  EditConcertView+Ticket.swift
//  concertjournal
//
//  Created by Paul Kühnel on 24.02.26.
//

import SwiftUI
#if DEBUG
import CoreData
#endif

extension ConcertEditView {

    @ViewBuilder
    func ticketSection() -> some View {
        VStack(alignment: .leading) {
            if let ticket = ticket {
                VStack(alignment: .leading, spacing: 8) {
                    Text(ticket.ticketType.label)
                        .font(.cjTitle)
                        .frame(maxWidth: .infinity, alignment: .center)

                    VStack {
                        Text(ticket.ticketCategory.label)
                            .font(.cjTitleF)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    .background {
                        RoundedRectangle(cornerRadius: 20).fill(ticket.ticketCategory.color)
                    }

                    switch ticket.ticketType {
                    case .seated:
                        Grid {
                            GridRow {
                                if ticket.seatBlock != nil {
                                    Text(TextKey.editconcertTicketSeatedBlock.localized)
                                        .font(.cjHeadline)
                                }
                                if ticket.seatRow != nil {
                                    Text(TextKey.editconcertTicketSeatedRow.localized)
                                        .font(.cjHeadline)
                                }
                                if ticket.seatNumber != nil {
                                    Text(TextKey.editconcertTicketSeatedSeat.localized)
                                        .font(.cjHeadline)
                                }
                            }
                            GridRow {
                                if let block = ticket.seatBlock {
                                    Text(block)
                                        .font(.cjTitle)
                                }
                                if let row = ticket.seatRow {
                                    Text(row)
                                        .font(.cjTitle)
                                }
                                if let seatNumber = ticket.seatNumber {
                                    Text(seatNumber)
                                        .font(.cjTitle)
                                }
                            }
                        }
                    case .standing:
                        if let standingPosition = ticket.standingPosition {
                            Text(standingPosition)
                                .font(.cjBody)
                        }
                    }

                    if let notes = ticket.notes {
                        Text(notes)
                            .font(.cjBody)
                            .padding(.horizontal)
                    }

                    if let ticketPrice = concert.ticket?.ticketPrice {
                        HStack {
                            Text(TextKey.editconcertTicketPrice.localized)
                                .font(.cjHeadline)

                            Text(ticketPrice.formatted)
                                .font(.cjTitle)
                                .conditionalRedacted(hidePrices)
                        }
                        .padding(.horizontal)
                        .contentShape(Rectangle())
                        .contextMenu {
                            Toggle(hidePrices ? TextKey.concertdetailContextShowPrices.localized : TextKey.concertdetailContextHidePrices.localized, isOn: $hidePrices)
                        }
                    }
                }
                .padding()
                .rectangleGlass()


                Button {
                    presentTicketEdit = true
                } label: {
                    Text(TextKey.editconcertEditTicket.localized)
                        .font(.cjBody)
                }
                .padding()
                .glassEffect()
            } else {
                Button {
                    presentTicketEdit = true
                } label: {
                    Text(TextKey.editconcertAddTicket.localized)
                        .font(.cjBody)
                }
                .padding()
                .glassEffect()
            }
        }
    }
}

#if DEBUG
#Preview {
    @Previewable @State var presenting: Bool = true

    let context = PreviewPersistenceController.shared.container.viewContext
    let concert = Concert.preview(in: context)

    VStack {
        Button("present") {
            presenting = true
        }
    }
    .sheet(isPresented: $presenting) {
        ConcertEditView(concert: concert, onSave: { _ in })
    }
}
#endif
