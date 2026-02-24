//
//  EditConcertView+Buddies.swift
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
    func buddiesSection() -> some View {
        if !buddyAttendees.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(buddyAttendees) { buddy in
                        VStack(spacing: 6) {
                            AvatarView(url: buddy.avatarURL, name: buddy.displayName, size: 40)
                            Text(buddy.displayName)
                                .font(.cjCaption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .frame(maxWidth: 56)
                        }
                        .overlay(alignment: .topTrailing) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    buddyAttendees.removeAll { $0.id == buddy.id }
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .padding()
            .rectangleGlass()
        }

        Button {
            buddyPickerPresenting = true
        } label: {
            Text(buddyAttendees.isEmpty ? "Begleiter hinzufügen" : "Begleiter bearbeiten")
                .font(.cjBody)
        }
        .padding()
        .glassEffect()
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
