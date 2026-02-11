import SwiftUI

// MARK: - Correlation Strength Bars
/// Visual indicator showing correlation strength (like WiFi bars)
struct CorrelationBars: View {
    let strength: CorrelationStrength
    @Environment(\.colorScheme) var colorScheme

    private var activeColor: Color {
        switch strength {
        case .weak: return AppColors.textSecondary
        case .moderate: return AppColors.warning
        case .strong: return AppColors.accent
        case .veryStrong: return AppColors.success
        }
    }

    private var inactiveColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.1)
    }

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...4, id: \.self) { bar in
                RoundedRectangle(cornerRadius: 1)
                    .fill(bar <= strength.rawValue ? activeColor : inactiveColor)
                    .frame(width: 2, height: CGFloat(bar * 2 + 2))
            }
        }
    }
}
