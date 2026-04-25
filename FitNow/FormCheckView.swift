import SwiftUI
import AVFoundation
import Vision

// MARK: - FormCheckView

struct FormCheckView: View {
    @StateObject private var service = FormCheckService()
    @State private var showExercisePicker = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            FormCameraPreview(service: service)
                .ignoresSafeArea()

            VStack {
                topBar
                Spacer()
                if let result = service.result {
                    feedbackBanner(result)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.horizontal, 20)
                }
                Spacer().frame(height: 40)
            }
        }
        .navigationTitle("Form Check")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Seleccionar ejercicio", isPresented: $showExercisePicker, titleVisibility: .visible) {
            ForEach(FormExercise.allCases) { ex in
                Button(ex.rawValue) { service.currentExercise = ex }
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.black.opacity(0.5), in: Circle())
            }
            Spacer()
            Button {
                showExercisePicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: service.currentExercise.sfSymbol)
                        .font(.system(size: 13, weight: .semibold))
                    Text(service.currentExercise.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color.black.opacity(0.5), in: Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }

    private func feedbackBanner(_ result: FormCheckResult) -> some View {
        HStack(spacing: 14) {
            scoreRing(result.score)
            VStack(alignment: .leading, spacing: 4) {
                Text(result.feedback)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.black.opacity(0.7))
                .overlay(RoundedRectangle(cornerRadius: 18)
                    .stroke(scoreColor(result.score).opacity(0.5), lineWidth: 1))
        )
    }

    private func scoreRing(_ score: Int) -> some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 4)
                .frame(width: 50, height: 50)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(scoreColor(score), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 50, height: 50)
                .rotationEffect(.degrees(-90))
            Text("\(score)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        score >= 80 ? .fnGreen : score >= 50 ? .fnYellow : .fnCrimson
    }
}

// MARK: - Camera preview with skeleton overlay

private struct FormCameraPreview: UIViewRepresentable {
    let service: FormCheckService

    func makeCoordinator() -> Coordinator { Coordinator(service: service) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black

        let session = context.coordinator.session
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device) else { return view }

        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        output.setSampleBufferDelegate(context.coordinator, queue: .global(qos: .userInteractive))
        session.addOutput(output)

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = UIScreen.main.bounds
        view.layer.addSublayer(preview)
        context.coordinator.previewLayer = preview

        let overlay = SkeletonOverlayView()
        overlay.frame = UIScreen.main.bounds
        overlay.backgroundColor = .clear
        view.addSubview(overlay)
        context.coordinator.overlayView = overlay

        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let result = service.result {
            context.coordinator.overlayView?.update(joints: result.joints)
        }
    }

    final class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        let session = AVCaptureSession()
        let service: FormCheckService
        var previewLayer: AVCaptureVideoPreviewLayer?
        var overlayView: SkeletonOverlayView?
        private var frameCount = 0

        init(service: FormCheckService) { self.service = service }

        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                           from connection: AVCaptureConnection) {
            frameCount += 1
            guard frameCount % 10 == 0,
                  let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            Task { await service.analyse(pixelBuffer: pixelBuffer) }
        }
    }
}

// MARK: - Skeleton overlay UIView

private final class SkeletonOverlayView: UIView {
    private var joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]

    func update(joints: [VNHumanBodyPoseObservation.JointName: CGPoint]) {
        self.joints = joints
        DispatchQueue.main.async { self.setNeedsDisplay() }
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let dotColor = UIColor(Color.fnPurple).withAlphaComponent(0.85)
        let lineColor = UIColor.white.withAlphaComponent(0.45)

        // Draw joint dots
        for (_, point) in joints {
            let screen = CGPoint(x: point.x * rect.width, y: point.y * rect.height)
            ctx.setFillColor(dotColor.cgColor)
            ctx.fillEllipse(in: CGRect(x: screen.x - 5, y: screen.y - 5, width: 10, height: 10))
        }

        // Draw limb connections
        let connections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
            (.leftShoulder, .rightShoulder), (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
            (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
            (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
            (.leftHip, .rightHip), (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
            (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
        ]

        ctx.setStrokeColor(lineColor.cgColor)
        ctx.setLineWidth(2)

        for (a, b) in connections {
            guard let pA = joints[a], let pB = joints[b] else { continue }
            ctx.move(to: CGPoint(x: pA.x * rect.width, y: pA.y * rect.height))
            ctx.addLine(to: CGPoint(x: pB.x * rect.width, y: pB.y * rect.height))
            ctx.strokePath()
        }
    }
}
