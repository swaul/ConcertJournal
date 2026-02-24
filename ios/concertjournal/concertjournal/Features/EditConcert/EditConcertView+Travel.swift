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
                        Text(TextKey.durationWas.localized(with: parsedDuration))
                    }
                    if let travelDistance = travel.travelDistance {
                        let parsedDistance = DistanceParser.format(travelDistance)
                        Text(TextKey.distanceWas.localized(with: parsedDistance))
                    }
                    if let arrivedAt = travel.arrivedAt {
                        Text(TextKey.arrived.localized(with: arrivedAt.timeOnlyString))
                    }
                    if let travelExpenses = travel.travelExpenses {
                        Text(TextKey.costWas.localized(with: travelExpenses.formatted))
                    }
                    if let hotelExpenses = travel.hotelExpenses {
                        Text(TextKey.hotelCost.localized(with: hotelExpenses.formatted))
                    }
                }
                .font(.cjBody)
                .padding()
                .rectangleGlass()
            }

            Button {
                editTravelPresenting = true
            } label: {
                Text(TextKey.addTravelInfo.localized)
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
