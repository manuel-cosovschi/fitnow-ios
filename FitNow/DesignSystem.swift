import SwiftUI

// MARK: - FitNow Design System
// Centralized design tokens, gradients, typography, and reusable components

// ─────────────────────────────────────────────────────────────────────────────
// MARK: Color Palette
// ─────────────────────────────────────────────────────────────────────────────

extension Color {
    // Brand / accent
    static let fnPrimary   = Color(red: 1.00, green: 0.42, blue: 0.21)  // #FF6B35 energetic orange
    static let fnSecondary = Color(red: 1.00, green: 0.23, blue: 0.19)  // #FF3B30 fierce red
    static let fnCyan      = Color(red: 0.00, green: 0.73, blue: 1.00)  // #00BAFF electric blue
    static let fnGreen     = Color(red: 0.19, green: 0.82, blue: 0.35)  // #30D158 success green
    static let fnPurple    = Color(red: 0.69, green: 0.32, blue: 0.99)  // #B052FC vivid purple
    static let fnYellow    = Color(red: 1.00, green: 0.62, blue: 0.04)  // #FF9F0A warm amber
    static let fnPink      = Color(red: 1.00, green: 0.22, blue: 0.56)  // #FF3890 neon pink

    // Semantic aliases
    static let fnSuccess = Color.fnGreen
    static let fnWarning = Color.fnYellow
    static let fnError   = Color.fnSecondary
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: Gradient Library
// ─────────────────────────────────────────────────────────────────────────────

struct FNGradient {
    // Primary brand – orange to red (buttons, headers, CTAs)
    static let primary = LinearGradient(
        colors: [.fnPrimary, .fnSecondary],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    // Running / metrics – cyan to blue
    static let run = LinearGradient(
        colors: [.fnCyan, Color(red: 0.00, green: 0.44, blue: 0.98)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    // Achievement / success
    static let success = LinearGradient(
        colors: [.fnGreen, Color(red: 0.07, green: 0.65, blue: 0.20)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    // Trainer – orange + amber
    static let trainer = LinearGradient(
        colors: [.fnPrimary, .fnYellow],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    // Club – purple
    static let club = LinearGradient(
        colors: [.fnPurple, Color(red: 0.40, green: 0.10, blue: 0.90)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    // Gym – cyan to deep blue
    static let gym = LinearGradient(
        colors: [.fnCyan, Color(red: 0.00, green: 0.38, blue: 0.82)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    // Sport – green
    static let sport = LinearGradient(
        colors: [.fnGreen, Color(red: 0.00, green: 0.55, blue: 0.25)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    // Premium dark (cards, sections)
    static let dark = LinearGradient(
        colors: [Color(.secondarySystemBackground), Color(.tertiarySystemBackground)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: Shadow System
// ─────────────────────────────────────────────────────────────────────────────

extension View {
    func fnShadow(
        color: Color = Color.black.opacity(0.12),
        radius: CGFloat = 10,
        y: CGFloat = 4
    ) -> some View {
        self.shadow(color: color, radius: radius, x: 0, y: y)
    }

    func fnShadowBrand() -> some View {
        self.shadow(color: Color.fnPrimary.opacity(0.35), radius: 16, x: 0, y: 6)
    }

    func fnShadowColored(_ color: Color, radius: CGFloat = 12, y: CGFloat = 4) -> some View {
        self.shadow(color: color.opacity(0.28), radius: radius, x: 0, y: y)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: Button Styles
// ─────────────────────────────────────────────────────────────────────────────

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: FitNow Primary Button (gradient)
// ─────────────────────────────────────────────────────────────────────────────

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
                            .foregroundColor(.white)
                    }
                } else {
                    HStack(spacing: 8) {
                        if let icon = icon {
                            Image(systemName: icon)
                                .font(.system(size: 16, weight: .semibold))
                        }
                        Text(title)
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isDisabled ? AnyShapeStyle(Color(.tertiarySystemFill)) : AnyShapeStyle(gradient))
            )
            .opacity(isDisabled ? 0.55 : 1.0)
            .fnShadowBrand()
        }
        .disabled(isDisabled || isLoading)
        .buttonStyle(ScaleButtonStyle())
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: FitNow Outline Button
// ─────────────────────────────────────────────────────────────────────────────

struct FitNowOutlineButton: View {
    let title: String
    var icon: String? = nil
    var color: Color = .fnPrimary
    var height: CGFloat = 50
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
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

// ─────────────────────────────────────────────────────────────────────────────
// MARK: Activity Type Info
// ─────────────────────────────────────────────────────────────────────────────

struct ActivityTypeInfo {
    let label: String
    let color: Color
    let icon: String
    let gradient: LinearGradient

    static func from(kind: String) -> ActivityTypeInfo {
        switch kind {
        case "trainer":
            return .init(label: "Personal Trainer", color: .fnPrimary,  icon: "person.fill",         gradient: FNGradient.trainer)
        case "gym":
            return .init(label: "Gimnasio",         color: .fnCyan,    icon: "dumbbell.fill",        gradient: FNGradient.gym)
        case "club":
            return .init(label: "Club",             color: .fnPurple,  icon: "building.2.fill",      gradient: FNGradient.club)
        case "club_sport":
            return .init(label: "Deporte",          color: .fnGreen,   icon: "sportscourt.fill",     gradient: FNGradient.sport)
        default:
            return .init(label: "Actividad",        color: .fnYellow,  icon: "figure.mixed.cardio",  gradient: FNGradient.primary)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: Activity Type Badge
// ─────────────────────────────────────────────────────────────────────────────

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
        .background(Capsule().fill(info.color.opacity(0.14)))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: Difficulty Badge
// ─────────────────────────────────────────────────────────────────────────────

struct DifficultyBadge: View {
    let difficulty: String
    private var info: (String, Color) {
        switch difficulty.lowercased() {
        case "baja":  return ("Fácil",    .fnGreen)
        case "media": return ("Media",    .fnYellow)
        case "alta":  return ("Difícil",  .fnSecondary)
        default:      return (difficulty.capitalized, Color(.secondaryLabel))
        }
    }
    var body: some View {
        let (label, color) = info
        Text(label)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.14)))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: Stat Card
// ─────────────────────────────────────────────────────────────────────────────

struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    var color: Color = .fnPrimary

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }
            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .monospaced))
                .foregroundColor(Color(.label))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 16).fill(color.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.25), lineWidth: 1))
        )
        .fnShadowColored(color, radius: 8, y: 3)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: Metric Card (running HUD)
// ─────────────────────────────────────────────────────────────────────────────

struct MetricCard: View {
    let value: String
    let unit: String
    let label: String
    var accentColor: Color = .fnPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(.secondaryLabel))
                .textCase(.uppercase)
                .tracking(0.8)
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 26, weight: .heavy, design: .monospaced))
                    .foregroundColor(Color(.label))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(unit)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(.secondaryLabel))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(accentColor.opacity(0.25), lineWidth: 1)
                )
        )
        .fnShadow()
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: Progress Ring
// ─────────────────────────────────────────────────────────────────────────────

struct ProgressRing: View {
    let progress: Double
    let size: CGFloat
    var lineWidth: CGFloat = 8
    var gradient: LinearGradient = FNGradient.primary

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemFill), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 1.0, dampingFraction: 0.8), value: progress)
        }
        .frame(width: size, height: size)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: Skeleton Loading
// ─────────────────────────────────────────────────────────────────────────────

struct SkeletonView: View {
    var cornerRadius: CGFloat = 12
    @State private var phase: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(.tertiarySystemBackground))
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, Color(.secondarySystemBackground).opacity(0.9), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
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

// ─────────────────────────────────────────────────────────────────────────────
// MARK: Section Header
// ─────────────────────────────────────────────────────────────────────────────

struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(Color(.label))
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.fnPrimary)
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: Activity List Card
// ─────────────────────────────────────────────────────────────────────────────

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
                .fnShadowColored(typeInfo.color)

                VStack(alignment: .leading, spacing: 3) {
                    Text(activity.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(.label))
                        .lineLimit(2)
                    if let loc = activity.location, !loc.isEmpty {
                        Label(loc, systemImage: "mappin.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(.secondaryLabel))
                            .lineLimit(1)
                    }
                }
                Spacer()
                if let price = activity.price, price > 0 {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(String(format: "$%.0f", price))
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(Color(.label))
                        Text("/ mes")
                            .font(.system(size: 10))
                            .foregroundColor(Color(.secondaryLabel))
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
                        .foregroundColor(Color(.tertiaryLabel))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color(.tertiarySystemFill)))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .overlay(alignment: .leading) {
            typeInfo.color
                .frame(width: 4)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(typeInfo.color.opacity(0.14), lineWidth: 0.5)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .fnShadow()
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: Enrollment Row Card
// ─────────────────────────────────────────────────────────────────────────────

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
                    .foregroundColor(Color(.label))
                    .lineLimit(1)
                if let loc = item.location, !loc.isEmpty {
                    Label(loc, systemImage: "mappin.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(.secondaryLabel))
                        .lineLimit(1)
                }
                if let dateStr = item.date_start {
                    Text(fnPrettyDate(dateStr))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                if let price = item.price, price > 0 {
                    Text(String(format: "$%.0f", price))
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(.label))
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(.tertiaryLabel))
            }
        }
        .padding(14)
        .overlay(alignment: .leading) {
            typeInfo.color
                .frame(width: 4)
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(typeInfo.color.opacity(0.14), lineWidth: 0.5)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .fnShadow(radius: 8, y: 3)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: Info Row (news / features)
// ─────────────────────────────────────────────────────────────────────────────

struct FNInfoRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(.label))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Color(.secondaryLabel))
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
                )
        )
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: Premium Filter Chip
// ─────────────────────────────────────────────────────────────────────────────

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : Color(.secondaryLabel))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? AnyShapeStyle(FNGradient.primary) : AnyShapeStyle(Color(.tertiarySystemFill)))
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: Shared Date Formatter
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// MARK: Grain / Noise Overlay
// ─────────────────────────────────────────────────────────────────────────────

struct GrainOverlay: View {
    var opacity: Double = 0.045

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
