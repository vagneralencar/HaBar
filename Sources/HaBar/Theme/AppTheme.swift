import SwiftUI

public enum AppTheme {
    // MARK: - Palette
    public static let popoverBackground = Color(red: 0.09, green: 0.09, blue: 0.11).opacity(0.72)
    public static let amberAccent = Color(red: 0.96, green: 0.70, blue: 0.27)
    public static let cyanClimate = Color(red: 0.20, green: 0.68, blue: 0.90)
    public static let greenOnline = Color(red: 0.19, green: 0.82, blue: 0.35)
    public static let dangerRed = Color(red: 1.0, green: 0.42, blue: 0.38)

    public static let activeSceneFill = LinearGradient(
        colors: [
            Color(red: 0.78, green: 0.56, blue: 0.22).opacity(0.85),
            Color(red: 0.42, green: 0.25, blue: 0.68).opacity(0.85)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    public static let activeSceneBorder = LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.78, blue: 0.35),
            Color(red: 0.68, green: 0.40, blue: 0.98)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    // MARK: - Layout Constants
    public static let popoverWidth: CGFloat = 390
    public static let cardCornerRadius: CGFloat = 13
    public static let controlCornerRadius: CGFloat = 9
}

// MARK: - Reusable DRY View Modifiers

public struct GlassCardModifier: ViewModifier {
    public let cornerRadius: CGFloat
    public let fill: Color
    public let borderColor: Color
    public let lineWidth: CGFloat

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: lineWidth)
            )
    }
}

public extension View {
    func glassCard(
        cornerRadius: CGFloat = AppTheme.cardCornerRadius,
        fill: Color = Color.white.opacity(0.05),
        borderColor: Color = Color.white.opacity(0.09),
        lineWidth: CGFloat = 1.0
    ) -> some View {
        modifier(
            GlassCardModifier(
                cornerRadius: cornerRadius,
                fill: fill,
                borderColor: borderColor,
                lineWidth: lineWidth
            )
        )
    }

    func glassInputField() -> some View {
        self
            .textFieldStyle(.plain)
            .font(.system(size: 12.5))
            .padding(9)
            .glassCard(
                cornerRadius: AppTheme.controlCornerRadius,
                fill: Color.black.opacity(0.35),
                borderColor: Color.white.opacity(0.14)
            )
    }
}

// MARK: - Reusable Circular Header & Back Buttons

public struct CircularIconButton: View {
    public let systemName: String
    public let isHighlighted: Bool
    public let helpText: String
    public let action: () -> Void

    public init(
        systemName: String,
        isHighlighted: Bool = false,
        helpText: String = "",
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.isHighlighted = isHighlighted
        self.helpText = helpText
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Circle()
                .fill(isHighlighted ? Color.white.opacity(0.20) : Color.white.opacity(0.08))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: systemName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.82))
                )
                .overlay(
                    Circle().stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(helpText)
    }
}

public struct NavigationBackButton: View {
    public let label: String
    public let action: () -> Void

    public init(label: String = "Voltar", action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.68))
        }
        .buttonStyle(.plain)
    }
}
