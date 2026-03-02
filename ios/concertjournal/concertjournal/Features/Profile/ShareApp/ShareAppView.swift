//
//  ShareAppView.swift
//  concertjournal
//
//  Created by Paul Kühnel on 02.03.26.
//

import SwiftUI
import Photos

struct ShareAppView: View {

    @State var qrCode: UIImage? = nil

    var body: some View {
        VStack {
            if let qrCode {
                Image(uiImage: qrCode)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()

                Button {
                    saveImageToPhotos(qrCode)
                } label: {
                    Text("Speichern")
                }
                .padding()
                .glassEffect()

            } else {
                LoadingView()
            }
        }
        .task {
            generateQRCodeToApp()
        }
    }

    func saveImageToPhotos(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                print("Keine Berechtigung")
                return
            }

            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                if success {
                    print("Gespeichert 🎉")
                } else if let error = error {
                    print("Fehler:", error)
                }
            }
        }
    }

    private func generateQRCodeToApp() {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data("https://apps.apple.com/app/id6759755131".utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return }
        logSuccess("QR code image generated successfully")
        qrCode = UIImage(cgImage: cgImage)
    }
}
