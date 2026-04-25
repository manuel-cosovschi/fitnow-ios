import SwiftUI
import AVFoundation

// MARK: - QRScannerView

struct QRScannerView: View {
    let onScan: (String) -> Void
    let onCancel: () -> Void

    @State private var cameraPermission: AVAuthorizationStatus = .notDetermined
    @State private var torchOn = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch cameraPermission {
            case .authorized:
                scannerLayer
            case .denied, .restricted:
                permissionDeniedView
            default:
                Color.black.ignoresSafeArea()
            }
        }
        .onAppear { checkPermission() }
    }

    // MARK: - Scanner layer

    private var scannerLayer: some View {
        ZStack {
            CameraPreviewRepresentable(onScan: onScan, torchOn: $torchOn)
                .ignoresSafeArea()

            // Viewfinder overlay
            GeometryReader { geo in
                let size: CGFloat = min(geo.size.width, geo.size.height) * 0.65
                let x = (geo.size.width  - size) / 2
                let y = (geo.size.height - size) / 2

                // Dimmed areas
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: geo.size))
                    path.addRoundedRect(in: CGRect(x: x, y: y, width: size, height: size),
                                        cornerSize: CGSize(width: 16, height: 16))
                }
                .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))

                // Corner brackets
                let bracket: CGFloat = 24
                let lw: CGFloat = 3
                Group {
                    cornerBracket(x: x,        y: y,        hFlip: false, vFlip: false, len: bracket, lw: lw)
                    cornerBracket(x: x+size,   y: y,        hFlip: true,  vFlip: false, len: bracket, lw: lw)
                    cornerBracket(x: x,        y: y+size,   hFlip: false, vFlip: true,  len: bracket, lw: lw)
                    cornerBracket(x: x+size,   y: y+size,   hFlip: true,  vFlip: true,  len: bracket, lw: lw)
                }

                // Scan line animation
                ScanLineView(x: x, y: y, size: size)
            }

            // Controls
            VStack {
                HStack {
                    Button { onCancel() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.5), in: Circle())
                    }
                    Spacer()
                    Button { torchOn.toggle() } label: {
                        Image(systemName: torchOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(torchOn ? .fnAmber : .white)
                            .padding(10)
                            .background(Color.black.opacity(0.5), in: Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)

                Spacer()

                Text("Apuntá la cámara al código QR del atleta")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(Color.black.opacity(0.6), in: Capsule())
                    .padding(.bottom, 60)
            }
        }
    }

    private func cornerBracket(x: CGFloat, y: CGFloat, hFlip: Bool, vFlip: Bool,
                                len: CGFloat, lw: CGFloat) -> some View {
        let hSign: CGFloat = hFlip ? -1 : 1
        let vSign: CGFloat = vFlip ? -1 : 1
        return Path { p in
            p.move(to: CGPoint(x: x + hSign * len, y: y))
            p.addLine(to: CGPoint(x: x, y: y))
            p.addLine(to: CGPoint(x: x, y: y + vSign * len))
        }
        .stroke(Color.fnBlue, style: StrokeStyle(lineWidth: lw, lineCap: .round))
    }

    // MARK: - Permission denied

    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.slash.fill")
                .font(.system(size: 56))
                .foregroundColor(.fnAsh)
            Text("Cámara sin permiso")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            Text("Habilitá el acceso a la cámara en Ajustes para escanear códigos QR.")
                .font(.system(size: 14))
                .foregroundColor(.fnSlate)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Abrir Ajustes") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.fnBlue)
            Button("Cancelar") { onCancel() }
                .font(.system(size: 14))
                .foregroundColor(.fnSlate)
        }
    }

    // MARK: - Permission check

    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermission = .authorized
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraPermission = granted ? .authorized : .denied
                }
            }
        default:
            cameraPermission = AVCaptureDevice.authorizationStatus(for: .video)
        }
    }
}

// MARK: - Scan line animation

private struct ScanLineView: View {
    let x: CGFloat; let y: CGFloat; let size: CGFloat
    @State private var offset: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(colors: [.clear, .fnBlue.opacity(0.8), .clear],
                               startPoint: .leading, endPoint: .trailing)
            )
            .frame(width: size, height: 2)
            .position(x: x + size / 2, y: y + offset)
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: true)) {
                    offset = size
                }
            }
    }
}

// MARK: - AVFoundation camera preview

private struct CameraPreviewRepresentable: UIViewRepresentable {
    let onScan: (String) -> Void
    @Binding var torchOn: Bool

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let session = context.coordinator.session

        guard let device = AVCaptureDevice.default(for: .video),
              let input  = try? AVCaptureDeviceInput(device: device) else { return view }

        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        session.addOutput(output)
        output.setMetadataObjectsDelegate(context.coordinator, queue: .main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = UIScreen.main.bounds
        view.layer.addSublayer(preview)

        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch, device.isTorchAvailable else { return }
        try? device.lockForConfiguration()
        device.torchMode = torchOn ? .on : .off
        device.unlockForConfiguration()
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let session = AVCaptureSession()
        let onScan: (String) -> Void
        private var lastScanned: String?
        private var lastScanDate = Date.distantPast

        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput objects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard let obj = objects.first as? AVMetadataMachineReadableCodeObject,
                  let value = obj.stringValue else { return }
            let now = Date()
            guard value != lastScanned || now.timeIntervalSince(lastScanDate) > 2 else { return }
            lastScanned = value
            lastScanDate = now
            onScan(value)
        }
    }
}
