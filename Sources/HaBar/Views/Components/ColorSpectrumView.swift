import SwiftUI

public struct ColorSpectrumView: View {
    public let activePresetId: String?
    public let currentRGB: RGBColor
    public let onSelectPreset: (HAColorPreset) -> Void
    public let onSelectCustomRGB: (RGBColor) -> Void

    @State private var indicatorOffset: CGPoint? = nil

    private static let rainbowGradient = AngularGradient(
        gradient: Gradient(colors: [
            Color(red: 1.0, green: 0.38, blue: 0.18),
            Color(red: 1.0, green: 0.85, blue: 0.25),
            Color(red: 0.30, green: 0.95, blue: 0.40),
            Color(red: 0.25, green: 0.85, blue: 1.0),
            Color(red: 0.25, green: 0.35, blue: 1.0),
            Color(red: 0.85, green: 0.25, blue: 0.95),
            Color(red: 1.0, green: 0.38, blue: 0.18)
        ]),
        center: .bottom
    )

    public init(
        activePresetId: String?,
        currentRGB: RGBColor,
        onSelectPreset: @escaping (HAColorPreset) -> Void,
        onSelectCustomRGB: @escaping (RGBColor) -> Void
    ) {
        self.activePresetId = activePresetId
        self.currentRGB = currentRGB
        self.onSelectPreset = onSelectPreset
        self.onSelectCustomRGB = onSelectCustomRGB
    }

    public var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let domeRadius: CGFloat = 104
                let center = CGPoint(x: geo.size.width / 2.0, y: 132)

                ZStack {
                    SemiCircleShape()
                        .fill(Self.rainbowGradient)
                        .overlay(
                            SemiCircleShape()
                                .fill(
                                    RadialGradient(
                                        colors: [Color.white.opacity(0.92), Color.white.opacity(0.0)],
                                        center: .bottom,
                                        startRadius: 4,
                                        endRadius: domeRadius * 0.85
                                    )
                                )
                        )
                        .frame(width: domeRadius * 2, height: domeRadius)
                        .position(x: center.x, y: center.y - domeRadius / 2.0)

                    if let pt = indicatorOffset {
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 2.5)
                            .background(Circle().fill(currentRGB.swiftUIColor))
                            .frame(width: 18, height: 18)
                            .shadow(color: .black.opacity(0.5), radius: 3)
                            .position(pt)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let dx = value.location.x - center.x
                            let dy = min(0, value.location.y - center.y)
                            let dist = min(domeRadius, hypot(dx, dy))
                            let angle = atan2(-dy, dx)
                            indicatorOffset = CGPoint(
                                x: center.x + cos(angle) * dist,
                                y: center.y - sin(angle) * dist
                            )

                            let normalizedHue = 1.0 - (angle / .pi)
                            let saturation = max(0.15, Double(dist / domeRadius))
                            onSelectCustomRGB(Self.hsbToRGB(hue: Double(normalizedHue) * 0.85, saturation: saturation))
                        }
                )
            }
            .frame(height: 132)

            Divider()
                .background(Color.white.opacity(0.12))

            HStack(alignment: .top, spacing: 10) {
                ForEach(HAColorPreset.defaultPresets) { preset in
                    PresetSwatchButton(
                        preset: preset,
                        isSelected: activePresetId == preset.id
                    ) {
                        indicatorOffset = nil
                        onSelectPreset(preset)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
        }
        .glassCard(
            cornerRadius: 14,
            fill: Color.white.opacity(0.05),
            borderColor: Color.white.opacity(0.10)
        )
    }

    private static func hsbToRGB(hue: Double, saturation: Double) -> RGBColor {
        let nsColor = NSColor(hue: CGFloat(hue), saturation: CGFloat(saturation), brightness: 1.0, alpha: 1.0)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else {
            return .warmWhite
        }
        return RGBColor(
            Int((rgbColor.redComponent * 255.0).rounded()),
            Int((rgbColor.greenComponent * 255.0).rounded()),
            Int((rgbColor.blueComponent * 255.0).rounded())
        )
    }
}

private struct PresetSwatchButton: View {
    let preset: HAColorPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    if isSelected {
                        Circle()
                            .stroke(preset.swiftUIColor.opacity(0.9), lineWidth: 2)
                            .frame(width: 40, height: 40)
                            .shadow(color: preset.swiftUIColor.opacity(0.6), radius: 6)
                    }
                    Circle()
                        .fill(preset.swiftUIColor)
                        .frame(width: 32, height: 32)
                        .shadow(color: preset.swiftUIColor.opacity(0.45), radius: 5)
                }
                .frame(width: 42, height: 42)

                Text(preset.name)
                    .font(.system(size: 10.5, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(.white.opacity(isSelected ? 0.95 : 0.78))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let sub = preset.subtitle {
                    Text(sub)
                        .font(.system(size: 9.5, weight: .regular))
                        .foregroundColor(.white.opacity(0.48))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

private struct SemiCircleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.maxY)
        let radius = min(rect.width / 2.0, rect.height)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}
