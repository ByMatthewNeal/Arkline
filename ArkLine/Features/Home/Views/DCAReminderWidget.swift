import SwiftUI

struct DCAReminderWidget: View {
    let reminders: [DCAReminder]
    var onComplete: ((DCAReminder) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Today's DCA")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                NavigationLink(destination: DCAListView()) {
                    Text("See All")
                        .font(.caption)
                        .foregroundColor(Color(hex: "6366F1"))
                }
            }

            VStack(spacing: 12) {
                ForEach(reminders) { reminder in
                    DCAReminderCard(
                        reminder: reminder,
                        onComplete: { onComplete?(reminder) }
                    )
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - DCA Reminder Card
struct DCAReminderCard: View {
    let reminder: DCAReminder
    var onComplete: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            // Coin Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)

                Text(reminder.symbol.prefix(1))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text("\(reminder.amount.asCurrency) • \(reminder.frequency.displayName)")
                    .font(.caption)
                    .foregroundColor(Color(hex: "A1A1AA"))
            }

            Spacer()

            // Complete Button
            Button(action: { onComplete?() }) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Color(hex: "22C55E"))
            }
        }
        .padding(12)
        .glassCard(cornerRadius: 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(reminder.name), \(reminder.amount.asCurrency) \(reminder.frequency.displayName)")
    }
}

// MARK: - Placeholder DCA List View
// Note: Actual DCAListView is in Features/DCAReminder/Views/DCAListView.swift

#Preview {
    DCAReminderWidget(
        reminders: [
            DCAReminder(
                id: UUID(),
                userId: UUID(),
                symbol: "BTC",
                name: "Bitcoin",
                amount: 100,
                frequency: .weekly,
                totalPurchases: 52,
                completedPurchases: 12,
                notificationTime: Date(),
                startDate: Date(),
                nextReminderDate: Date(),
                isActive: true,
                createdAt: Date()
            )
        ],
        onComplete: { _ in }
    )
    .padding()
    .background(Color(hex: "0F0F0F"))
}
