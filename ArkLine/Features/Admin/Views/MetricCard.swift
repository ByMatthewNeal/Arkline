import SwiftUI

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: ArkSpacing.xs) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                Spacer()
            }

            HStack {
                Text(value)
                    .font(AppFonts.number24)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                Spacer()
            }

            HStack {
                Text(title)
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
            }
        }
        .padding(ArkSpacing.md)
        .glassCard(cornerRadius: 12)
    }
}

#Preview {
    HStack {
        MetricCard(title: "MRR", value: "$1,250", icon: "dollarsign.circle.fill", color: AppColors.success)
        MetricCard(title: "Active", value: "35", icon: "person.fill", color: AppColors.accent)
    }
    .padding()
    .background(AppColors.background(.dark))
}
