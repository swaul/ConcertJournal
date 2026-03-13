//
//  EditConcertView+Travel.swift
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
    func travelSection() -> some View {
        VStack(alignment: .leading) {
            if let travel = travel {
                VStack(alignment: .leading, spacing: 8) {
                    if let travelType = travel.travelType {
                        Text(travelType.infoText(color: dependencies.colorThemeManager.appTint))
                    }
                    if let travelDuration = travel.travelDuration {
                        let parsedDuration = DurationParser.format(travelDuration)
                        Text(TextKey.editconcertTravelDuration.localized(with: parsedDuration))
                    }
                    if let travelDistance = travel.travelDistance {
                        let parsedDistance = DistanceParser.format(travelDistance)
                        Text(TextKey.editconcertTravelDistance.localized(with: parsedDistance))
                    }
                    if let arrivedAt = travel.arrivedAt {
                        Text(TextKey.editconcertTravelArrivalTime.localized(with: arrivedAt.timeOnlyString))
                    }
                    if let travelExpenses = travel.travelExpenses {
                        Text(TextKey.editconcertTravelCost.localized(with: travelExpenses.formatted))
                    }
                    if let hotelExpenses = travel.hotelExpenses {
                        Text(TextKey.editconcertHotelCost.localized(with: hotelExpenses.formatted))
                    }
                }
                .font(.cjBody)
                .padding()
                .rectangleGlass()
            }

            Button {
                editTravelPresenting = true
            } label: {
                Text(TextKey.editconcertAddTravel.localized)
            }
            .padding()
            .glassEffect()
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
