import SwiftUI

struct QuickActionsBar: View {
    var body: some View {
        HStack(spacing: 12) {
            QuickActionButton(
                icon: "plus.circle.fill",
                label: "Add",
                color: Color(hex: "6366F1")
            ) {
                // Add transaction
            }

            QuickActionButton(
                icon: "arrow.left.arrow.right.circle.fill",
                label: "Transfer",
                color: Color(hex: "8B5CF6")
            ) {
                // Transfer
            }

            QuickActionButton(
                icon: "chart.pie.fill",
                label: "Portfolio",
                color: Color(hex: "22C55E")
            ) {
                // View portfolio
            }

            QuickActionButton(
                icon: "bell.badge.fill",
                label: "Alerts",
                color: Color(hex: "F97316")
            ) {
                // View alerts
            }
        }
    }
}

// MARK: - Quick Action Button
struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                    .frame(width: 56, height: 56)
                    .background(color.opacity(0.1))
                    .cornerRadius(16)

                Text(label)
                    .font(.caption2)
                    .foregroundColor(Color(hex: "A1A1AA"))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    QuickActionsBar()
        .padding()
        .background(Color(hex: "0F0F0F"))
}
