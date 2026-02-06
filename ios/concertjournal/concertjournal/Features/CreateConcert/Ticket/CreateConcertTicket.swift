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
    
    let artist: Artist?
    
    @State private var ticketCategory: TicketCategory = .regular
    @State private var ticketType: TicketType = .seated
    @State private var ticketPrice: String = ""

    @State private var seatBlock: String = ""
    @State private var seatRow: String = ""
    @State private var seatNumber: String = ""

    @State private var standingPosition: String = ""
    @State private var additionalNotes: String = ""
    
    @FocusState var descriptionFocus
    @FocusState var notesDescriptionFocus
    @FocusState var customTicketCategoryFocus
    
    @State var seatTypeAnimated: Bool = true
    @State var descriptionFocusAnimated = false
    @State var showCustomTicketCategoryTextField = false
    
    @State var problems: [Problem] = []
    @State var showProblems: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
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
                                .tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    Text("War das eine bestimmte Ticketkategorie?")
                        .padding(.horizontal)
                        .padding(.top)
                    
                    TabView(selection: $ticketCategory) {
                        ForEach(TicketCategory.allCases, id: \.self) { item in
                            VStack {
                                Text(item.label)
                                    .font(.cjTitle)
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
                    
                    if showProblems {
                        if let problem = problems.first(where: { $0 == .customButEmpty }) {
                            Text(problem.getProblemDescription())
                                .foregroundStyle(.red)
                                .padding(.horizontal)
                        }
                    }
                    
                    if seatTypeAnimated  {
                        Text("Was war die Ticket Nummer?")
                            .padding(.horizontal)
                            .transition(.offset(x: -400))
                            .padding(.top)
                        HStack {
                            VStack {
                                Text("Block")
                                    .frame(maxWidth: .infinity)
                                TextField("", text: $seatBlock, prompt: Text("C"))
                                    .multilineTextAlignment(.center)
                                    .padding()
                                    .glassEffect()
                                    .frame(width: 60)
                            }
                            .padding(4)
                            
                            VStack {
                                Text("Reihe")
                                    .frame(maxWidth: .infinity)
                                TextField("", text: $seatRow, prompt: Text("8"))
                                    .multilineTextAlignment(.center)
                                    .padding()
                                    .glassEffect()
                                    .frame(width: 60)
                            }
                            .padding(4)
                            
                            VStack {
                                Text("Sitz")
                                    .frame(maxWidth: .infinity)
                                TextField("", text: $seatNumber, prompt: Text("29"))
                                    .multilineTextAlignment(.center)
                                    .padding()
                                    .glassEffect()
                                    .frame(width: 60)
                            }
                            .padding(4)
                            
                        }
                        .padding(.horizontal)
                        .transition(.move(edge: .leading))
                        .onChange(of: seatRow) { _, newValue in
                            if !newValue.isEmpty {
                                withAnimation {
                                    self.problems.removeAll(where: { $0 == .seatButEmpty })
                                }
                            }
                        }
                        .onChange(of: seatNumber) { _, newValue in
                            if !newValue.isEmpty {
                                withAnimation {
                                    self.problems.removeAll(where: { $0 == .seatButEmpty })
                                }
                            }
                        }
                        
                        if showProblems {
                            if let problem = problems.first(where: { $0 == .seatButEmpty }) {
                                Text(problem.getProblemDescription())
                                    .foregroundStyle(.red)
                                    .padding(.horizontal)
                            }
                        }
                        
                    } else {
                        VStack {
                            HStack {
                                Text("Wo bist du gestanden?")
                                    .padding(.leading)
                                
                                Spacer()
                                
                                if descriptionFocusAnimated {
                                    Button {
                                        descriptionFocus = false
                                    } label: {
                                        Text("Abbrechen")
                                    }
                                    .padding(.trailing)
                                    .transition(.offset(y: 50))
                                }
                            }
                            
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
                        .transition(.move(edge: .trailing))
                    }
                    
                    Text("Notes")
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
            .onChange(of: ticketType, { _, newValue in
                withAnimation(.bouncy) {
                    seatTypeAnimated = (newValue == .seated)
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
                        
                    } label: {
                        Text("Speichern")
                            .font(.cjBody)
                    }
                }
            }
            .navigationTitle("Ticket info")
        }
    }
    
    enum Problem {
        case customButEmpty
        case seatButEmpty
        
        func getProblemDescription() -> String {
            switch self {
            case .customButEmpty:
                return "You selected a custom ticket type. Please enter a name for it"
            case .seatButEmpty:
                return "You selected seating, but didn't add a row or seat number"
            }
        }
    }
}

#Preview {
    CreateConcertTicket(artist: Artist(artist: .taylorSwift))
}
