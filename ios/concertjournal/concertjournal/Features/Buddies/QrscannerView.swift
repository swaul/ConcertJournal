//
//  QRScannerView.swift
//  concertjournal
//

import AVFoundation
import SwiftUI

// MARK: - Public SwiftUI Wrapper

struct QRScannerView: View {
    let onScanned: (String) -> Void
    @State private var coordinator = ScannerCoordinator()
    @State private var permissionDenied = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            if permissionDenied {
                permissionDeniedView()
            } else {
                // Live Camera
                CameraPreviewRepresentable(coordinator: coordinator)
                    .ignoresSafeArea()
                
                // Overlay
                scannerOverlay()
            }
        }
        .navigationTitle("QR-Code scannen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { dismiss() }
                    .font(.cjBody)
            }
        }
        .onAppear {
            coordinator.onScanned = { code in
                onScanned(code)
                dismiss()
            }
            Task { await requestCameraPermission() }
        }
        .onDisappear {
            coordinator.stopSession()
        }
    }
    
    // MARK: - Overlay
    
    @ViewBuilder
    private func scannerOverlay() -> some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) * 0.65
            let rect = CGRect(
                x: (geo.size.width - side) / 2,
                y: (geo.size.height - side) / 2 - 40,
                width: side,
                height: side
            )
            
            ZStack {
                // Dimmed außerhalb
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .mask {
                        Rectangle()
                            .ignoresSafeArea()
                            .overlay {
                                RoundedRectangle(cornerRadius: 20)
                                    .frame(width: side, height: side)
                                    .position(x: rect.midX, y: rect.midY)
                                    .blendMode(.destinationOut)
                            }
                    }
                
                // Rahmen
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white, lineWidth: 2)
                    .frame(width: side, height: side)
                    .position(x: rect.midX, y: rect.midY)
                
                // Ecken-Highlights
                CornerBrackets(side: side)
                    .position(x: rect.midX, y: rect.midY)
                
                // Hinweistext
                VStack(spacing: 8) {
                    Text(TextKey.scanHint.localized)
                        .font(.cjBody)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .position(x: geo.size.width / 2, y: rect.maxY + 36)
            }
        }
    }
    
    // MARK: - Permission Denied
    
    @ViewBuilder
    private func permissionDeniedView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill.badge.ellipsis")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            
            Text(TextKey.cameraAccessDenied.localized)
                .font(.cjTitle2)
                .fontWeight(.semibold)
            
            Text(TextKey.accessDeniedDesc.localized)
                .font(.cjBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button(TextKey.openSettings.localized) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.glassProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.background.ignoresSafeArea())
    }
    
    // MARK: - Permission
    
    private func requestCameraPermission() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            coordinator.configure()
            coordinator.startSession()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                coordinator.configure()
                coordinator.startSession()
            } else {
                permissionDenied = true
            }
        default:
            permissionDenied = true
        }
    }
}

// MARK: - Corner Brackets

private struct CornerBrackets: View {
    let side: CGFloat
    private let length: CGFloat = 28
    private let thickness: CGFloat = 4
    private let radius: CGFloat = 20
    
    var body: some View {
        ZStack {
            ForEach(Corner.allCases, id: \.self) { corner in
                BracketShape(corner: corner, length: length, thickness: thickness, radius: radius)
                    .frame(width: side, height: side)
                    .foregroundStyle(.tint)
            }
        }
    }
    
    enum Corner: CaseIterable { case topLeft, topRight, bottomLeft, bottomRight }
    
    struct BracketShape: Shape {
        let corner: Corner
        let length: CGFloat
        let thickness: CGFloat
        let radius: CGFloat
        
        func path(in rect: CGRect) -> Path {
            var p = Path()
            switch corner {
            case .topLeft:
                p.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
                p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
                p.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY),
                               control: CGPoint(x: rect.minX, y: rect.minY))
                p.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))
            case .topRight:
                p.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
                p.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
                p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                               control: CGPoint(x: rect.maxX, y: rect.minY))
                p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + length))
            case .bottomLeft:
                p.move(to: CGPoint(x: rect.minX, y: rect.maxY - length))
                p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
                p.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.maxY),
                               control: CGPoint(x: rect.minX, y: rect.maxY))
                p.addLine(to: CGPoint(x: rect.minX + length, y: rect.maxY))
            case .bottomRight:
                p.move(to: CGPoint(x: rect.maxX - length, y: rect.maxY))
                p.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.maxY))
                p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY - radius),
                               control: CGPoint(x: rect.maxX, y: rect.maxY))
                p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
            }
            return p
        }
    }
}

// MARK: - AVFoundation Coordinator

@Observable
final class ScannerCoordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    var onScanned: ((String) -> Void)?
    
    // Session wird einmalig erstellt und nie neu gebaut
    let session = AVCaptureSession()
    private var isConfigured = false
    private var hasScanned = false
    
    /// Session konfigurieren – nur einmal aufrufen
    func configure() {
        guard !isConfigured else { return }
        isConfigured = true
        
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        
        session.addInput(input)
        
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
    }
    
    /// Session starten – auf Background-Queue
    func startSession() {
        hasScanned = false
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }
    
    /// Session stoppen
    func stopSession() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }
    
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasScanned,
              let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = obj.stringValue else { return }
        
        hasScanned = true
        HapticManager.shared.buttonTap()
        onScanned?(code)
    }
}

// MARK: - UIKit Camera Preview

private struct CameraPreviewRepresentable: UIViewRepresentable {
    let coordinator: ScannerCoordinator
    
    func makeUIView(context: Context) -> PreviewView {
        // Session ist bereits konfiguriert – nur noch Preview Layer zuweisen
        let view = PreviewView()
        view.previewLayer.session = coordinator.session
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        // Nichts zu tun – Session ändert sich nicht
    }
    
    class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = bounds
        }
    }
}
