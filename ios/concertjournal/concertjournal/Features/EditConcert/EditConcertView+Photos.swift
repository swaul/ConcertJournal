//
//  EditConcertView+Photos.swift
//  concertjournal
//
//  Created by Paul Kühnel on 24.02.26.
//

import PhotosUI
import SwiftUI
#if DEBUG
import CoreData
#endif

extension ConcertEditView {

    @ViewBuilder
    func photosSection() -> some View {
        VStack(alignment: .leading) {
            // Bestehende Fotos
            if !existingPhotos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(existingPhotos) { photo in
                            let image = dependencies.offlinePhotoRepsitory.loadImage(for: photo)
                            ZStack(alignment: .topTrailing) {
                                Group {
                                    if let image {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                    } else {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.secondary.opacity(0.2))
                                    }
                                }
                                .frame(width: 90, height: 90)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                                Button {
                                    HapticManager.shared.buttonTap()
                                    photosToDelete.append(photo)
                                    existingPhotos.removeAll { $0.id == photo.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                                .offset(x: 6, y: -6)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // Neue Fotos
            if !newImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(newImages.indices, id: \.self) { index in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: newImages[index])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 90, height: 90)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                Button {
                                    HapticManager.shared.buttonTap()
                                    selectedPhotoItems.remove(at: index)
                                    newImages.remove(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                                .offset(x: 6, y: -6)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // Picker Button
            PhotosPicker(
                selection: $selectedPhotoItems,
                maxSelectionCount: 10,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label("Fotos hinzufügen", systemImage: "photo.on.rectangle.angled")
                    .font(.cjBody)
            }
            .onChange(of: selectedPhotoItems) { _, newItems in
                Task {
                    newImages.removeAll()
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            newImages.append(image)
                        }
                    }
                }
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
