import SwiftUI

// MARK: - Color Hex Init

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch h.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - Color Palette

extension Color {
    // ── Brand / Accent ────────────────────────────────────────────────────────
    static let fnBlue    = Color(red: 0.12, green: 0.56, blue: 1.00)   // #1E90FF
    static let fnCobalt  = Color(red: 0.25, green: 0.41, blue: 0.88)   // #4169E1
    static let fnIce     = Color(red: 0.66, green: 0.78, blue: 0.98)   // #A8C7FA
    static let fnGreen   = Color(red: 0.00, green: 0.90, blue: 0.46)   // #00E676
    static let fnAmber   = Color(red: 1.00, green: 0.70, blue: 0.00)   // #FFB300
    static let fnCrimson = Color(red: 1.00, green: 0.19, blue: 0.33)   // #FF3055
    static let fnPurple  = Color(red: 0.48, green: 0.32, blue: 0.97)   // #7B52F8

    // ── Surfaces (dark mode nativo) ───────────────────────────────────────────
    static let fnBg       = Color(red: 0.04, green: 0.09, blue: 0.16)  // #0A1628
    static let fnSurface  = Color(red: 0.07, green: 0.13, blue: 0.25)  // #112240
    static let fnElevated = Color(red: 0.10, green: 0.20, blue: 0.34)  // #1A3356
    static let fnBorder   = Color(red: 0.14, green: 0.23, blue: 0.33)  // #243B55

    // ── Text ──────────────────────────────────────────────────────────────────
    static let fnWhite = Color(red: 0.91, green: 0.94, blue: 0.996)    // #E8F0FE
    static let fnSlate = Color(red: 0.53, green: 0.60, blue: 0.67)     // #8899AA
    static let fnAsh   = Color(red: 0.27, green: 0.33, blue: 0.40)     // #445566

    // ── Legacy aliases (files not yet migrated use these) ────────────────────
    static let fnPrimary   = Color.fnBlue
    static let fnSecondary = Color.fnCrimson
    static let fnCyan      = Color.fnBlue
    static let fnYellow    = Color.fnAmber
}

// MARK: - Gradient Library

struct FNGradient {
    /// Primary CTA — azul eléctrico
    static let primary = LinearGradient(
        colors: [.fnBlue, .fnCobalt],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    /// Verde éxito (confirmaciones, inscripciones)
    static let success = LinearGradient(
        colors: [.fnGreen, Color(hex: "#00AA55")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    /// Rojo danger (admin, acciones destructivas)
    static let danger = LinearGradient(
        colors: [.fnCrimson, Color(hex: "#CC0033")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    /// Proveedor (púrpura)
    static let provider = LinearGradient(
        colors: [.fnPurple, Color(hex: "#5533CC")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    /// Trainer (amber)
    static let trainer = LinearGradient(
        colors: [.fnAmber, Color(hex: "#E65100")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    // Legacy aliases used in the pre-redesign code
    static let run     = primary
    static let gym     = primary
    static let club    = provider
    static let sport   = success
    static let dark    = LinearGradient(
        colors: [.fnSurface, .fnElevated],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static func forKind(_ kind: String) -> LinearGradient {
        switch kind {
        case "trainer":    return .trainer
        case "gym":        return .primary
        case "club":       return .provider
        case "club_sport": return .success
        default:           return .primary
        }
    }
}

// MARK: - Shadow Helpers

extension View {
    func fnShadow(color: Color = .black.opacity(0.25),
                  radius: CGFloat = 16, y: CGFloat = 4) -> some View {
        self.shadow(color: color, radius: radius, x: 0, y: y)
    }
    func fnShadowBrand() -> some View {
        self.shadow(color: Color.fnBlue.opacity(0.35), radius: 24, x: 0, y: 8)
    }
    func fnShadowColored(_ color: Color,
                          radius: CGFloat = 24, y: CGFloat = 8) -> some View {
        self.shadow(color: color.opacity(0.30), radius: radius, x: 0, y: y)
    }
}

// MARK: - Button Styles

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.18, dampingFraction: 0.7),
                       value: configuration.isPressed)
    }
}

// MARK: - Primary Button

struct FitNowButton: View {
    let title: String
    var icon: String? = nil
    var gradient: LinearGradient = FNGradient.primary
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var height: CGFloat = 54
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(0.82)
                        Text("Cargando...")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.fnWhite)
                    }
                } else {
                    HStack(spacing: 8) {
                        if let icon {
                            Image(systemName: icon)
                                .font(.system(size: 16, weight: .semibold))
                        }
                        Text(title)
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.fnWhite)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isDisabled
                          ? AnyShapeStyle(Color.fnElevated)
                          : AnyShapeStyle(gradient))
            )
            .opacity(isDisabled ? 0.55 : 1.0)
            .fnShadowBrand()
        }
        .disabled(isDisabled || isLoading)
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Outline Button

struct FitNowOutlineButton: View {
    let title: String
    var icon: String? = nil
    var color: Color = .fnBlue
    var height: CGFloat = 50
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(color.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(color.opacity(0.35), lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Activity Type Info

struct ActivityTypeInfo {
    let label: String
    let color: Color
    let icon: String
    let gradient: LinearGradient

    static func from(kind: String) -> ActivityTypeInfo {
        switch kind {
        case "trainer":
            return .init(label: "Personal Trainer", color: .fnAmber,
                         icon: "person.fill", gradient: FNGradient.trainer)
        case "gym":
            return .init(label: "Gimnasio", color: .fnBlue,
                         icon: "dumbbell.fill", gradient: FNGradient.primary)
        case "club":
            return .init(label: "Club", color: .fnPurple,
                         icon: "building.2.fill", gradient: FNGradient.provider)
        case "club_sport":
            return .init(label: "Deporte", color: .fnGreen,
                         icon: "sportscourt.fill", gradient: FNGradient.success)
        default:
            return .init(label: "Actividad", color: .fnBlue,
                         icon: "figure.mixed.cardio", gradient: FNGradient.primary)
        }
    }
}

// MARK: - Type Badge

struct ActivityTypeBadge: View {
    let kind: String
    var body: some View {
        let info = ActivityTypeInfo.from(kind: kind)
        HStack(spacing: 4) {
            Image(systemName: info.icon)
                .font(.system(size: 9, weight: .bold))
            Text(info.label)
                .font(.system(size: 10, weight: .bold))
                .lineLimit(1)
        }
        .foregroundColor(info.color)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(info.color.opacity(0.18)))
    }
}

// MARK: - Difficulty Badge

struct DifficultyBadge: View {
    let difficulty: String
    private var info: (String, Color) {
        switch difficulty.lowercased() {
        case "baja":  return ("Fácil", .fnGreen)
        case "media": return ("Media", .fnAmber)
        case "alta":  return ("Difícil", .fnCrimson)
        default:      return (difficulty.capitalized, .fnSlate)
        }
    }
    var body: some View {
        let (label, color) = info
        Text(label)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.18)))
    }
}

// MARK: - Glass Stat Card

struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    var color: Color = .fnBlue

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(color.opacity(0.20)).frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }
            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .monospaced))
                .foregroundColor(.fnWhite)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.fnSlate)
                .textCase(.uppercase)
                .tracking(0.5)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.fnBg.opacity(0.75))
                .overlay(RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.fnBorder, lineWidth: 1))
        )
        .fnShadow()
    }
}

// MARK: - Metric Card (run HUD)

struct MetricCard: View {
    let value: String
    let unit: String
    let label: String
    var accentColor: Color = .fnBlue

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.fnSlate)
                .textCase(.uppercase)
                .tracking(0.8)
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 26, weight: .heavy, design: .monospaced))
                    .foregroundColor(.fnWhite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.fnSlate)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.fnSurface)
                .overlay(RoundedRectangle(cornerRadius: 16)
                            .stroke(accentColor.opacity(0.25), lineWidth: 1))
        )
        .fnShadow()
    }
}

// MARK: - Progress Ring

struct ProgressRing: View {
    let progress: Double
    let size: CGFloat
    var lineWidth: CGFloat = 8
    var gradient: LinearGradient = FNGradient.primary

    var body: some View {
        ZStack {
            Circle().stroke(Color.fnBorder, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(gradient,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 1.0, dampingFraction: 0.8),
                           value: progress)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Skeleton

struct SkeletonView: View {
    var cornerRadius: CGFloat = 12
    @State private var phase: CGFloat = 0
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.fnSurface)
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, Color.fnElevated.opacity(0.9), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: -geo.size.width + geo.size.width * 2 * phase)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            )
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.fnWhite)
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.fnBlue)
                }
            }
        }
    }
}

// MARK: - Activity List Card

struct ActivityListCard: View {
    let activity: Activity
    private var typeInfo: ActivityTypeInfo {
        ActivityTypeInfo.from(kind: activity.kind ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(typeInfo.gradient)
                        .frame(width: 50, height: 50)
                    Image(systemName: typeInfo.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }
                .fnShadowColored(typeInfo.color, radius: 12, y: 4)

                VStack(alignment: .leading, spacing: 3) {
                    Text(activity.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.fnWhite)
                        .lineLimit(2)
                    if let loc = activity.location, !loc.isEmpty {
                        Label(loc, systemImage: "mappin.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.fnSlate)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if let price = activity.price, price > 0 {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(String(format: "$%.0f", price))
                            .font(.system(size: 16, weight: .heavy, design: .monospaced))
                            .foregroundColor(.fnWhite)
                        Text("/ mes")
                            .font(.system(size: 10))
                            .foregroundColor(.fnSlate)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            HStack(spacing: 6) {
                ActivityTypeBadge(kind: activity.kind ?? "")
                if let diff = activity.difficulty, !diff.isEmpty {
                    DifficultyBadge(difficulty: diff)
                }
                if let mod = activity.modality, !mod.isEmpty {
                    Text(mod.capitalized)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.fnSlate)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.fnElevated))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.fnAsh)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .overlay(alignment: .leading) {
            typeInfo.color.frame(width: 3)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.fnSurface)
                .overlay(RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.fnBorder, lineWidth: 0.5))
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .fnShadow()
    }
}

// MARK: - Enrollment Row Card

struct EnrollmentRowCard: View {
    let item: EnrollmentItem
    let onCancel: (() -> Void)?

    private var typeInfo: ActivityTypeInfo {
        ActivityTypeInfo.from(kind: item.activity_kind ?? "")
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(typeInfo.gradient)
                    .frame(width: 46, height: 46)
                Image(systemName: typeInfo.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            .fnShadowColored(typeInfo.color, radius: 8, y: 3)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.fnWhite)
                    .lineLimit(1)
                if let loc = item.location, !loc.isEmpty {
                    Label(loc, systemImage: "mappin.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.fnSlate)
                        .lineLimit(1)
                }
                if let dateStr = item.date_start {
                    Text(fnPrettyDate(dateStr))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(typeInfo.color)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                if let price = item.price, price > 0 {
                    Text(String(format: "$%.0f", price))
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .foregroundColor(.fnWhite)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.fnAsh)
            }
        }
        .padding(14)
        .overlay(alignment: .leading) { typeInfo.color.frame(width: 3) }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.fnSurface)
                .overlay(RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.fnBorder, lineWidth: 0.5))
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .fnShadow(radius: 8, y: 3)
    }
}

// MARK: - Info Row

struct FNInfoRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(iconColor.opacity(0.20)).frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.fnWhite)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.fnSlate)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.fnSurface)
                .overlay(RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.fnBorder, lineWidth: 0.5))
        )
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : .fnSlate)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected
                              ? AnyShapeStyle(FNGradient.primary)
                              : AnyShapeStyle(Color.fnSurface))
                        .overlay(Capsule()
                            .stroke(Color.fnBorder, lineWidth: isSelected ? 0 : 1))
                )
        }
        .buttonStyle(ScaleButtonStyle())
        .shadow(color: isSelected ? Color.fnBlue.opacity(0.35) : .clear, radius: 10, y: 4)
    }
}

// MARK: - Glass Card

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.fnBg.opacity(0.75))
                    .overlay(RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(Color.fnBorder, lineWidth: 1))
            )
    }
}

// MARK: - Grain Overlay

struct GrainOverlay: View {
    var opacity: Double = 0.03
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 2
            var x: CGFloat = 0
            while x < size.width {
                var y: CGFloat = 0
                while y < size.height {
                    let v = ((Int(x) &* 1619 &+ Int(y) &* 31337) >> 4) & 0xFF
                    if v > 170 {
                        let alpha = Double(v - 170) / 85.0 * opacity
                        context.fill(
                            Path(CGRect(x: x, y: y, width: 1, height: 1)),
                            with: .color(.white.opacity(alpha))
                        )
                    }
                    y += step
                }
                x += step
            }
        }
        .allowsHitTesting(false)
        .drawingGroup()
    }
}

// MARK: - Shared Date Formatter

private let _fnIsoFrac: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()
private let _fnIsoBasic: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()
private let _fnMySQL: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT: 0)
    f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return f
}()
private let _fnOut: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "es_AR")
    f.dateStyle = .medium
    f.timeStyle = .short
    return f
}()

func fnPrettyDate(_ s: String) -> String {
    if let d = _fnIsoFrac.date(from: s) ?? _fnIsoBasic.date(from: s) ?? _fnMySQL.date(from: s) {
        return _fnOut.string(from: d)
    }
    return s
}
