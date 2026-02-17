import SwiftUI

/// The ArkLine "A" logo rendered as a vector shape.
/// Use with `.fill(style: FillStyle(eoFill: true))` for a monochrome silhouette watermark.
struct ArkLineLogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height

        var path = Path()

        // Outer boundary — the combined silhouette of both overlapping triangles
        path.move(to: CGPoint(x: w * 0.48, y: h * 0.05))     // Apex
        path.addLine(to: CGPoint(x: w * 0.91, y: h * 0.83))  // Right point
        path.addLine(to: CGPoint(x: w * 0.79, y: h * 0.95))  // Bottom right
        path.addLine(to: CGPoint(x: w * 0.11, y: h * 0.95))  // Bottom left
        path.closeSubpath()

        // Inner triangular cutout — the "A" hole (wound opposite for even-odd fill)
        path.move(to: CGPoint(x: w * 0.41, y: h * 0.69))
        path.addLine(to: CGPoint(x: w * 0.49, y: h * 0.87))
        path.addLine(to: CGPoint(x: w * 0.61, y: h * 0.78))
        path.closeSubpath()

        return path
    }
}

/// A subtle watermark overlay showing the ArkLine logo silhouette.
/// Adapts to light/dark mode automatically.
struct ChartLogoWatermark: View {
    @Environment(\.colorScheme) var colorScheme
    var size: CGFloat = 48

    var body: some View {
        ArkLineLogoShape()
            .fill(
                colorScheme == .dark ? Color.white : Color.black,
                style: FillStyle(eoFill: true)
            )
            .frame(width: size, height: size)
            .opacity(colorScheme == .dark ? 0.04 : 0.06)
    }
}
