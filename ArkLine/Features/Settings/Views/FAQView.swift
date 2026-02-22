import SwiftUI

// MARK: - FAQ View
struct FAQView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    let faqs = [
        FAQItem(question: "What is ArkLine?", answer: "ArkLine is a crypto sentiment tracking app that helps you understand market trends, track your portfolio, and make informed investment decisions."),
        FAQItem(question: "How does the sentiment analysis work?", answer: "We aggregate data from multiple sources including social media, news, and market data to calculate real-time sentiment scores for cryptocurrencies."),
        FAQItem(question: "What is DCA?", answer: "DCA (Dollar-Cost Averaging) is an investment strategy where you invest a fixed amount at regular intervals, regardless of the asset's price."),
        FAQItem(question: "How do I set up price alerts?", answer: "Go to your Profile > Alerts and tap 'Add Alert'. Select the cryptocurrency, set your target price, and choose whether to be notified when the price goes above or below your target."),
        FAQItem(question: "Is my data secure?", answer: "Yes, we use industry-standard encryption and security practices. Your data is stored securely and we never share your personal information with third parties."),
        FAQItem(question: "How do I delete my account?", answer: "Go to Settings > Account > Delete Account. Please note that this action is irreversible and all your data will be permanently deleted.")
    ]

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()
            List {
                ForEach(faqs) { faq in
                    FAQRow(faq: faq)
                }
                .listRowBackground(AppColors.cardBackground(colorScheme))
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.sidebar)
            #endif
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("FAQ")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - FAQ Item
struct FAQItem: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

// MARK: - FAQ Row
struct FAQRow: View {
    @Environment(\.colorScheme) var colorScheme
    let faq: FAQItem
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Text(faq.question)
                        .font(AppFonts.body14Medium)
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                        .multilineTextAlignment(.leading)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(AppColors.textSecondary)
                        .font(.system(size: 14))
                }
            }

            if isExpanded {
                Text(faq.answer)
                    .font(AppFonts.body14)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}
