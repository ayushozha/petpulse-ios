import SwiftUI

// MARK: - Logo

struct HeartShape: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY + h * 0.28))
        p.addCurve(to: CGPoint(x: r.minX, y: r.minY + h * 0.32),
                   control1: CGPoint(x: r.midX - w * 0.12, y: r.minY - h * 0.02),
                   control2: CGPoint(x: r.minX, y: r.minY + h * 0.02))
        p.addCurve(to: CGPoint(x: r.midX, y: r.maxY),
                   control1: CGPoint(x: r.minX, y: r.minY + h * 0.62),
                   control2: CGPoint(x: r.midX - w * 0.22, y: r.minY + h * 0.80))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.minY + h * 0.32),
                   control1: CGPoint(x: r.midX + w * 0.22, y: r.minY + h * 0.80),
                   control2: CGPoint(x: r.maxX, y: r.minY + h * 0.62))
        p.addCurve(to: CGPoint(x: r.midX, y: r.minY + h * 0.28),
                   control1: CGPoint(x: r.maxX, y: r.minY + h * 0.02),
                   control2: CGPoint(x: r.midX + w * 0.12, y: r.minY - h * 0.02))
        p.closeSubpath()
        return p
    }
}

struct PulseShape: Shape {
    func path(in r: CGRect) -> Path {
        let points: [(CGFloat, CGFloat)] = [(0, 0.5), (0.3, 0.5), (0.42, 0.1), (0.56, 0.9), (0.68, 0.35), (0.78, 0.5), (1, 0.5)]
        var p = Path()
        for (i, point) in points.enumerated() {
            let cg = CGPoint(x: r.minX + r.width * point.0, y: r.minY + r.height * point.1)
            if i == 0 { p.move(to: cg) } else { p.addLine(to: cg) }
        }
        return p
    }
}

/// Heart, paw and pulse mark.
struct LogoMark: View {
    var size: CGFloat = 64

    var body: some View {
        HStack(spacing: -size * 0.06) {
            HeartShape()
                .fill(PP.logoGradient)
                .frame(width: size, height: size * 0.9)
                .overlay {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: size * 0.42))
                        .foregroundStyle(.white)
                        .offset(y: -size * 0.04)
                }
            PulseShape()
                .stroke(PP.teal, style: StrokeStyle(lineWidth: max(1.5, size * 0.035), lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.42, height: size * 0.4)
        }
    }
}

struct Wordmark: View {
    var size: CGFloat = 40

    var body: some View {
        (Text("Pet").foregroundColor(PP.navy) + Text("Pulse").foregroundColor(PP.teal))
            .font(.pp(size, .bold))
    }
}

// MARK: - Icons

/// Pet bowl drawn from two shapes, since SF Symbols has no bowl.
struct BowlIcon: View {
    var color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: w * 0.14, y: h * 0.42))
                    p.addLine(to: CGPoint(x: w * 0.86, y: h * 0.42))
                    p.addLine(to: CGPoint(x: w, y: h * 0.82))
                    p.addLine(to: CGPoint(x: 0, y: h * 0.82))
                    p.closeSubpath()
                }
                .fill(color)
                Ellipse()
                    .fill(color.opacity(0.55))
                    .frame(width: w * 0.72, height: h * 0.3)
                    .position(x: w * 0.5, y: h * 0.4)
            }
        }
    }
}

enum IconKind {
    case metric(Metric)
    case coat, camera, weight

    var soft: Color {
        switch self {
        case .metric(let metric): metric.soft
        case .coat: Color(hex: 0xECE8FB)
        case .camera: Color(hex: 0xECE8FB)
        case .weight: PP.blueSoft
        }
    }
}

/// Round tinted badge used for every metric row.
struct IconBadge: View {
    var kind: IconKind
    var size: CGFloat = 40

    var body: some View {
        Circle()
            .fill(kind.soft)
            .frame(width: size, height: size)
            .overlay { glyph }
    }

    @ViewBuilder private var glyph: some View {
        switch kind {
        case .metric(.dryFood), .metric(.wetFood):
            if case .metric(let metric) = kind {
                BowlIcon(color: metric.tint).frame(width: size * 0.52, height: size * 0.46)
            }
        case .metric(.water):
            symbol("drop.fill", Metric.water.tint)
        case .metric(.stool):
            Text("💩").font(.system(size: size * 0.5))
        case .metric(.activity):
            symbol("cat.fill", Metric.activity.tint)
        case .coat:
            symbol("sparkles", Color(hex: 0x7468D4))
        case .camera:
            symbol("camera.fill", Color(hex: 0x7468D4))
        case .weight:
            symbol("scalemass.fill", PP.blue)
        }
    }

    private func symbol(_ name: String, _ color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(color)
    }
}

// MARK: - Building blocks

struct PrimaryButton: View {
    var title: String
    var systemImage: String?
    var leadingImage: String?
    var action: () -> Void

    init(_ title: String, systemImage: String? = nil, leadingImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.leadingImage = leadingImage
        self.action = action
    }

    var body: some View {
        Button(action: action) { PrimaryButtonLabel(title: title, systemImage: systemImage, leadingImage: leadingImage) }
            .buttonStyle(.plain)
    }
}

struct PrimaryButtonLabel: View {
    var title: String
    var systemImage: String?
    var leadingImage: String?

    var body: some View {
        HStack(spacing: 8) {
            if let leadingImage { Image(systemName: leadingImage) }
            Text(title)
            if let systemImage { Image(systemName: systemImage) }
        }
        .font(.pp(17, .semibold))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(PP.buttonGradient, in: Capsule())
        .shadow(color: PP.teal.opacity(0.3), radius: 8, y: 4)
        .contentShape(Capsule())
    }
}

/// White outlined capsule for an alternative to the `PrimaryButton` beside it.
struct SecondaryButton: View {
    var title: String
    var leadingImage: String?
    var action: () -> Void

    init(_ title: String, leadingImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.leadingImage = leadingImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let leadingImage { Image(systemName: leadingImage) }
                Text(title)
            }
            .font(.pp(17, .semibold))
            .foregroundStyle(PP.teal)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(.white, in: Capsule())
            .overlay(Capsule().stroke(PP.teal.opacity(0.5), lineWidth: 1.5))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

extension View {
    /// White rounded card with a hairline border and soft shadow.
    func card(radius: CGFloat = 16, padding: CGFloat = 14) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(PP.stroke, lineWidth: 1))
            .shadow(color: PP.navy.opacity(0.05), radius: 6, y: 2)
    }

    /// Standard pushed-screen chrome: mint background, hidden system bar, custom header.
    func screen<Trailing: View>(_ title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) -> some View {
        self.safeAreaInset(edge: .top, spacing: 0) { ScreenHeader(title: title, trailing: trailing()) }
            .background(PP.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
    }
}

struct ScreenHeader<Trailing: View>: View {
    var title: String
    var trailing: Trailing
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Text(title).font(.pp(18, .semibold)).foregroundStyle(PP.navy)
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(PP.navy)
                        .frame(width: 44, height: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Back")
                Spacer()
                trailing
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 48)
        .background(.white.opacity(0.9))
    }
}

struct SectionTitle: View {
    var text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).font(.pp(16, .semibold)).foregroundStyle(PP.navy)
    }
}

struct PhotoView: View {
    var ref: PhotoRef

    var body: some View {
        image.resizable().scaledToFill()
    }

    private var image: Image {
        switch ref {
        case .asset(let name): Image(name)
        case .data(let data): UIImage(data: data).map(Image.init(uiImage:)) ?? Image("cat_avatar")
        }
    }
}

/// Square rounded photo tile.
struct PhotoTile: View {
    var ref: PhotoRef
    var size: CGFloat = 62
    var radius: CGFloat = 10

    var body: some View {
        PhotoView(ref: ref)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

/// "↓ 40%" or "No significant change".
struct ChangeValue: View {
    var change: MetricChange?

    var body: some View {
        if let change, change.isSignificant {
            HStack(spacing: 6) {
                Image(systemName: change.isDecrease ? "arrow.down" : "arrow.up")
                    .font(.system(size: 13, weight: .bold))
                Text("\(change.percent)%").font(.pp(15, .semibold))
            }
            .foregroundStyle(PP.red)
        } else {
            Text("No significant change").font(.pp(13)).foregroundStyle(PP.subtext)
        }
    }
}

struct MetricChangeRow: View {
    var metric: Metric
    var change: MetricChange?
    var iconSize: CGFloat = 32

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(kind: .metric(metric), size: iconSize)
            Text(metric.changeTitle).font(.pp(15)).foregroundStyle(PP.text)
            Spacer()
            ChangeValue(change: change)
        }
    }
}

extension ChangeReport {
    /// Rows shown under "What changed?": the core appetite and activity signals, plus anything else flagged.
    var displayMetrics: [Metric] {
        let core: [Metric] = [.dryFood, .activity, .wetFood]
        return core + significant.map(\.metric).filter { !core.contains($0) }
    }
}
