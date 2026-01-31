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
                Section("Konzert") {
                    TextField("Titel", text: $title)
                    DatePicker("Datum", selection: $date, displayedComponents: .date)
                }

                Button {
                    selectVenuePresenting = true
                } label: {
                    if !venueName.isEmpty {
                        VStack(alignment: .leading) {
                            Text(venueName)
                            if let city = venue?.city {
                                Text(city)
                            }
                        }
                        .padding()
                    } else {
                        Text("Select Venue (optional)")
                            .padding()
                    }
                }
                .buttonStyle(.glass)
                .padding(.horizontal)
                
                Section("Notizen") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 120)
                }

                Section("Bewertung") {
                    Stepper(value: $rating, in: 0...10) {
                        HStack {
                            Text("Rating")
                            Spacer()
                            Text("\(rating)")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .glassEffect()
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Konzert bearbeiten")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
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
