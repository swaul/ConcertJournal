//
//  CreateConcertTicket.swift
//  concertjournal
//
//  Created by Paul Kühnel on 05.02.26.
//

import SwiftUI

struct CreateConcertTicket: View {
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var dependencies

    init(artist: Artist? = nil, ticketInfo: Ticket? = nil, onSave: @escaping (Ticket) -> Void) {
        self.artist = artist
        self.onSave = onSave

        self.ticketCategory = ticketInfo?.ticketCategory ?? .regular
        self.ticketType = ticketInfo?.ticketType ?? .seated
        self.ticketPrice = ticketInfo?.ticketPrice?.formatted ?? ""
        self.seatBlock = ticketInfo?.seatBlock ?? ""
        self.seatRow = ticketInfo?.seatRow ?? ""
        self.seatNumber = ticketInfo?.seatNumber ?? ""
        self.standingPosition = ticketInfo?.standingPosition ?? ""
        self.additionalNotes = ticketInfo?.notes ?? ""
        self.showPriceEmoji = false
        
        if let ticketInfo {
            self.seatTypeAnimated = ticketInfo.ticketType == .seated
            self.ticketCategoryAnimated = ticketInfo.ticketCategory
        } else {
            self.seatTypeAnimated = true
            self.ticketCategoryAnimated = .regular
        }
    }

    let artist: Artist?

    var onSave: (Ticket) -> Void

    @State private var ticketCategory: TicketCategory
    @State private var ticketType: TicketType
    @State private var ticketPrice: String

    @State private var seatBlock: String
    @State private var seatRow: String
    @State private var seatNumber: String

    @State private var standingPosition: String
    @State private var additionalNotes: String
    
    @FocusState var descriptionFocus
    @FocusState var notesDescriptionFocus

    @State var seatTypeAnimated: Bool
    @State var ticketCategoryAnimated: TicketCategory
    @State var descriptionFocusAnimated = false

    var body: some View {
        NavigationStack {
            ZStack {
                ticketCategoryAnimated.color
                    .ignoresSafeArea()
                Color(uiColor: .systemBackground)
                    .clipShape(Capsule())
                    .ignoresSafeArea()
                    .padding(.vertical, 10)
                    .padding(.horizontal, 30)
                    .blur(radius: 100)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if let artist {
                            Text("Was für ein Ticket hattest du für \(artist.name)")
                                .font(.cjTitle)
                                .padding(.horizontal)
                        } else {
                            Text("Was für ein Ticket hattest du")
                                .font(.cjTitle)
                                .padding(.horizontal)
                        }

                        Picker("", selection: $ticketType) {
                            ForEach(TicketType.allCases, id: \.self) { item in
                                Text(item.label)
                                    .font(.cjHeadline)
                                    .tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .font(.cjHeadline)

                        ticketCategorySection()

                        priceSection()

                        if seatTypeAnimated  {
                            seatedSection()
                                .transition(.move(edge: .leading))
                        } else {
                            standingSection()
                            .transition(.move(edge: .trailing))
                        }

                        Text("Notes")
                            .font(.cjHeadline)
                            .padding(.horizontal)
                            .padding(.top)

                        TextEditor(text: $additionalNotes)
                            .focused($notesDescriptionFocus)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 120)
                            .padding()
                            .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .circular))
                            .padding(.horizontal)
                            .font(.cjBody)
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
            }
            .onChange(of: ticketType, { _, newValue in
                withAnimation(.bouncy) {
                    seatTypeAnimated = (newValue == .seated)
                }
            })
            .onChange(of: ticketCategory, { _, newValue in
                withAnimation(.bouncy) {
                    ticketCategoryAnimated = newValue
                }
            })
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Abbrechen")
                            .font(.cjBody)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveTicketInfo()
                    } label: {
                        Text("Speichern")
                            .font(.cjBody)
                    }
                }
            }
            .navigationTitle("Ticket info")
        }
        .interactiveDismissDisabled()
    }

    @ViewBuilder
    private func ticketCategorySection() -> some View {
        VStack {
            Text("War das eine bestimmte Ticketkategorie?")
                .padding(.horizontal)
                .padding(.top)
                .font(.cjHeadline)
            Text("(wischen für mehr)")
                .font(.cjFootnote)
                .padding(.horizontal)

            TabView(selection: $ticketCategory) {
                ForEach(TicketCategory.allCases, id: \.self) { item in
                    VStack {
                        Text(item.label)
                            .font(.cjTitleF)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background {
                        RoundedRectangle(cornerRadius: 25)
                            .fill(item.color)
                    }
                    .tag(item)
                    .padding()
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 100)
            .frame(maxWidth: .infinity)
        }
    }

    @State var showPriceEmoji: Bool = false

    private func priceSection() -> some View {
        HStack(alignment: .firstTextBaseline) {
                Text("Ticket preis:")
                    .font(.cjHeadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ExpensesValidatedTextField("49,99 €", text: $ticketPrice)
                    .frame(width: 120)
                    .multilineTextAlignment(.trailing)
                    .font(.cjTitle)
                    .overlay {
                        if showPriceEmoji {
                            Text("🥲")
                                .font(.cjLargeTitle)
                                .offset(x: 50, y: -45)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .onChange(of: ticketPrice) { _, newValue in
                        if (ExpensesParser.parse(newValue)?.value ?? 0) > 1000.0 {
                            withAnimation(.bouncy) {
                                showPriceEmoji = true
                            }
                        } else if showPriceEmoji == true {
                            withAnimation(.bouncy) {
                                showPriceEmoji = false
                            }
                        }
                    }
            }
        .padding(.horizontal)
    }

    @FocusState var blockTextFieldFocused
    @FocusState var rowTextFieldFocused
    @FocusState var seatTextFieldFocused

    @ViewBuilder
    private func seatedSection() -> some View {
        VStack {
            Text("Was war die Ticket Nummer?")
                .font(.cjHeadline)
                .padding(.horizontal)
                .transition(.move(edge: .leading))
                .padding(.top)
            HStack {
                VStack {
                    Text("Block")
                        .frame(maxWidth: .infinity)
                        .font(.cjHeadline)
                    TextField("", text: $seatBlock, prompt: Text("C").font(.cjTitle))
                        .focused($blockTextFieldFocused)
                        .multilineTextAlignment(.center)
                        .padding()
                        .glassEffect()
                        .font(.cjTitle)
                        .submitLabel(.next)
                        .onSubmit {
                            rowTextFieldFocused = true
                        }
                }
                .padding(4)

                VStack {
                    Text("Reihe")
                        .frame(maxWidth: .infinity)
                        .font(.cjHeadline)
                    TextField("", text: $seatRow, prompt: Text("8").font(.cjTitle))
                        .focused($rowTextFieldFocused)
                        .multilineTextAlignment(.center)
                        .padding()
                        .glassEffect()
                        .font(.cjTitle)
                        .submitLabel(.next)
                        .onSubmit {
                            seatTextFieldFocused = true
                        }
                }
                .padding(4)

                VStack {
                    Text("Sitz")
                        .frame(maxWidth: .infinity)
                        .font(.cjHeadline)
                    TextField("", text: $seatNumber, prompt: Text("29").font(.cjTitle))
                        .focused($seatTextFieldFocused)
                        .multilineTextAlignment(.center)
                        .padding()
                        .glassEffect()
                        .font(.cjTitle)
                }
                .padding(4)

            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func standingSection() -> some View {
        VStack {
            Text("Wo bist du gestanden?")
                .padding(.leading)
                .font(.cjHeadline)

            TextEditor(text: $standingPosition)
                .focused($descriptionFocus)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
                .padding()
                .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .circular))
                .padding(.horizontal)
                .font(.cjBody)
        }
        .padding(.top)
    }

    private func saveTicketInfo() {
        let ticket = Ticket(ticketType: ticketType,
            ticketCategory: ticketCategory,
            ticketPrice: ExpensesParser.parse(ticketPrice),
            seatBlock: seatBlock.nilIfEmpty,
            seatRow: seatRow.nilIfEmpty,
            seatNumber: seatNumber.nilIfEmpty,
            standingPosition: standingPosition.nilIfEmpty,
            notes: additionalNotes.nilIfEmpty)

        onSave(ticket)
    }
}

#Preview {
    CreateConcertTicket(artist: Artist(artist: .taylorSwift), onSave: { _ in })
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
