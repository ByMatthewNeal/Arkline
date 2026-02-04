import SwiftUI

/// A standardized disclaimer view displayed at the bottom of financial screens.
struct FinancialDisclaimer: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Text("This app does not provide financial or investment advice. Always do your own research and consult a licensed advisor before making crypto-related decisions")
            .font(AppFonts.caption12)
            .foregroundColor(AppColors.textSecondary.opacity(0.7))
            .multilineTextAlignment(.center)
            .padding(.vertical, 8)
    }
}

#Preview {
    FinancialDisclaimer()
        .padding()
}
