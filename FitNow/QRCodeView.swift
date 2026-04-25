import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - QRCodeView

struct QRCodeView: View {
    let content: String
    var size: CGFloat = 200

    var body: some View {
        if let image = generateQR(content) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.fnElevated)
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "qrcode")
                        .font(.system(size: size * 0.4))
                        .foregroundColor(.fnAsh)
                )
        }
    }

    private func generateQR(_ string: String) -> UIImage? {
        let context = CIContext()
        let filter  = CIFilter.qrCodeGenerator()
        filter.setValue(Data(string.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let ciImage = filter.outputImage else { return nil }

        let scale = size / ciImage.extent.width
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Enrollment QR Card

struct EnrollmentQRCard: View {
    let enrollmentId: Int
    let activityTitle: String
    let date: String?

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("Tu código de acceso")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.fnSlate)
                Text(activityTitle)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.fnWhite)
                    .multilineTextAlignment(.center)
                if let date {
                    Text(date)
                        .font(.system(size: 13))
                        .foregroundColor(.fnSlate)
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.white)
                    .frame(width: 220, height: 220)

                QRCodeView(content: "fitnow://checkin/\(enrollmentId)", size: 196)
            }

            VStack(spacing: 4) {
                Text("ID: \(enrollmentId)")
                    .font(.custom("JetBrains Mono", size: 16).weight(.bold))
                    .foregroundColor(.fnWhite)
                    .tracking(2)
                Text("Mostralo en la entrada")
                    .font(.system(size: 12))
                    .foregroundColor(.fnSlate)
            }
        }
        .padding(24)
        .background(Color.fnElevated, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.fnBorder, lineWidth: 1))
    }
}
