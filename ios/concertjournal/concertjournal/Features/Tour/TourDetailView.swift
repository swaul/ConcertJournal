//
//  TourDetailView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 24.02.26.
//

import SwiftUI

struct TourDetailView: View {
    @Environment(\.dependencies) private var dependencies
    let tour: Tour
    @State private var showEditTour = false
    @State private var showAddConcert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Tour Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(tour.name)
                        .font(.cjTitle)

                    if let artist = tour.artist {
                        Text(artist.name)
                            .font(.cjHeadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("\(tour.startDate.formatted(date: .abbreviated, time: .omitted)) - \(tour.endDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.cjBody)

                        Spacer()

                        TourStatusBadge(status: tour.status)
                    }
                }
                .padding()

                // Tour Beschreibung
                if let description = tour.tourDescription, !description.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Beschreibung")
                            .font(.cjHeadline)
                        Text(description)
                            .font(.cjBody)
                    }
                    .padding()
                }

                // Konzerte dieser Tour
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Konzerte (\(tour.concertCount))")
                            .font(.cjHeadline)

                        Spacer()

                        Button(action: { showAddConcert = true }) {
                            Image(systemName: "plus.circle.fill")
                        }
                    }

                    if tour.concertsArray.isEmpty {
                        Text("Keine Konzerte dieser Tour zugeordnet")
                            .font(.cjBody)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(tour.concertsArray, id: \.id) { concert in
                                ConcertRowInTour(concert: concert, tour: tour)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Tour")
        .toolbar {
            Button(action: { showEditTour = true }) {
                Image(systemName: "pencil.circle.fill")
            }
        }
        //        .sheet(isPresented: $showEditTour) {
        //            EditTourView(tour: tour)
        //        }
        //        .sheet(isPresented: $showAddConcert) {
        //            AddConcertToTourView(tour: tour)
        //        }
    }
}

struct ConcertRowInTour: View {
    let concert: Concert
    let tour: Tour
    @Environment(\.dependencies) private var dependencies

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(concert.artist.name)
                    .font(.cjHeadline)

                if let venue = concert.venue {
                    Text("\(venue.name), \(concert.city ?? "")")
                        .font(.cjBody)
                        .foregroundStyle(.secondary)
                }

                Text(concert.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            let rating = Int(concert.rating)
            if rating > 0 {
                HStack(spacing: 2) {
                    ForEach(0..<rating, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}
