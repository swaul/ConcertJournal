//
//  EditConcertView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 05.01.26.
//

import SwiftUI
import Supabase

struct ConcertEditView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var date: Date
    @State private var notes: String
    @State private var rating: Int
    @State private var venueName: String
    
    @State private var venue: Venue?

    @State private var selectVenuePresenting = false

    let concert: FullConcertVisit
    
    let onSave: (ConcertUpdate) -> Void

    init(concert: FullConcertVisit, onSave: @escaping (ConcertUpdate) -> Void) {
        _title = State(initialValue: concert.title ?? "")
        _date = State(initialValue: concert.date)
        _notes = State(initialValue: concert.notes ?? "")
        _rating = State(initialValue: concert.rating ?? 0)
        _venueName = State(initialValue: concert.venue?.name ?? "")
        _venue = State(initialValue: concert.venue)

        self.concert = concert
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Titel", text: $title)
                    DatePicker("Datum", selection: $date, displayedComponents: .date)
                } header: {
                    Text("Konzert")
                        .font(.cjBody)
                }

                Section {
                    Button {
                        selectVenuePresenting = true
                    } label: {
                        if !venueName.isEmpty {
                            VStack(alignment: .leading) {
                                Text(venueName)
                                    .font(.cjBody)
                                if let city = venue?.city {
                                    Text(city)
                                        .font(.cjBody)
                                }
                            }
                        } else {
                            Text("Venue auswählen (optional)")
                                .font(.cjBody)
                        }
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Location")
                        .font(.cjBody)
                }
                
                Section {
                    TextEditor(text: $notes)
                        .frame(minHeight: 120)
                        .font(.cjBody)
                } header: {
                    Text("Notizen")
                        .font(.cjBody)
                }

                Section {
                    Stepper(value: $rating, in: 0...10) {
                        HStack {
                            Text("Rating")
                                .font(.cjBody)
                            Spacer()
                            Text("\(rating)")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .font(.cjBody)
                        }
                    }
                } header: {
                    Text("Bewertung")
                        .font(.cjBody)
                }
            }
            .navigationTitle("Konzert bearbeiten")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Abbrechen")
                            .font(.cjBody)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onSave(
                            ConcertUpdate(
                                title: title,
                                date: date,
                                notes: notes,
                                venue: venue,
                                city: venue?.city,
                                rating: rating
                            )
                        )
                        dismiss()
                    } label: {
                        Text("Speichern")
                            .font(.cjBody)
                    }
                }
            }
            .sheet(isPresented: $selectVenuePresenting) {
                CreateConcertSelectVenueView(isPresented: $selectVenuePresenting, onSelect: { venue in
                    self.venueName = venue.name
                    self.venue = venue
                })
            }
        }
    }
}

struct ConcertUpdate {
    let title: String
    let date: Date
    let notes: String
    let venue: Venue?
    let city: String?
    let rating: Int
}
