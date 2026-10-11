import SwiftUI

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

/// PetPulse design tokens, taken from the mockup.
enum PP {
    static let teal = Color(hex: 0x23A9AC)
    static let tealLight = Color(hex: 0x4CC5B4)
    static let navy = Color(hex: 0x1D3557)
    static let text = Color(hex: 0x2B3A4A)
    static let subtext = Color(hex: 0x70808F)
    static let mint = Color(hex: 0xE4F5F2)
    static let stroke = Color(hex: 0xDDEBEA)
    static let green = Color(hex: 0x34B77C)
    static let orange = Color(hex: 0xF5A623)
    static let orangeSoft = Color(hex: 0xFFF1DC)
    static let red = Color(hex: 0xE5484D)
    static let blue = Color(hex: 0x2F7FD3)
    static let blueSoft = Color(hex: 0xE6F1FC)

    static let buttonGradient = LinearGradient(colors: [tealLight, teal], startPoint: .leading, endPoint: .trailing)
    static let logoGradient = LinearGradient(colors: [Color(hex: 0x5FD39A), teal, Color(hex: 0x3D9BE0)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
    static let background = LinearGradient(colors: [.white, mint], startPoint: .top, endPoint: .bottom)
}

extension Font {
    static func pp(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// Built-in iOS script face for the handwritten captions.
    static func handwriting(_ size: CGFloat) -> Font { .custom("BradleyHandITCTT-Bold", size: size) }
}

extension Metric {
    var tint: Color {
        switch self {
        case .dryFood: Color(hex: 0xF0718A)
        case .wetFood: PP.green
        case .water: Color(hex: 0x3C8FE4)
        case .stool: Color(hex: 0x8A5A3B)
        case .activity: Color(hex: 0x7468D4)
        }
    }

    var soft: Color {
        switch self {
        case .dryFood: Color(hex: 0xFDE4E8)
        case .wetFood: Color(hex: 0xDFF5EA)
        case .water: Color(hex: 0xE1EFFD)
        case .stool: Color(hex: 0xF7E8D9)
        case .activity: Color(hex: 0xE9E6FB)
        }
    }
}

extension Date {
    /// "Oct 10, 2026"
    var mediumLabel: String { formatted(.dateTime.month(.abbreviated).day().year()) }
    /// "Oct 10"
    var shortLabel: String { formatted(.dateTime.month(.abbreviated).day()) }
}

extension Data {
    /// Shrinks a picked photo so the store stays small.
    func downscaledJPEG(maxSide: CGFloat = 1200) -> Data {
        guard let image = UIImage(data: self) else { return self }
        let scale = Swift.min(1, maxSide / Swift.max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.8) ?? self
    }
}
