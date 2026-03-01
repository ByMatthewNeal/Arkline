import SwiftUI

// MARK: - FAQ View
struct FAQView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    let faqs = [
        FAQItem(question: "What is ArkLine?", answer: "ArkLine is a crypto and finance sentiment tracking app that helps you understand market trends, track your portfolio, and make informed investment decisions using real-time data and risk analysis."),
        FAQItem(question: "How does the sentiment analysis work?", answer: "We aggregate data from multiple sources including social media, news, on-chain metrics, and market data to calculate real-time sentiment scores for cryptocurrencies."),
        FAQItem(question: "What is the ArkLine Risk Score?", answer: "The ArkLine Risk Score is a proprietary metric that combines macro indicators (DXY, M2, VIX, WTI), sentiment data, and on-chain signals to give you an overall picture of market risk. It updates daily and is displayed on your Home Screen."),
        FAQItem(question: "What is DCA?", answer: "DCA (Dollar-Cost Averaging) is an investment strategy where you invest a fixed amount at regular intervals, regardless of the asset's price. You can set up DCA reminders in the app to stay consistent with your investment schedule."),
        FAQItem(question: "How do Insights & Broadcasts work?", answer: "Insights are market updates and analysis published by the ArkLine team. You'll receive push notifications for new insights, and you can react with emojis and view attached charts, portfolio showcases, and app references."),
        FAQItem(question: "How do I refer friends to ArkLine?", answer: "Go to your Profile and tap 'Refer Friends'. You'll get a unique referral code (ARK-XXXXXX) that you can share via text, email, or social media. Your referral count tracks how many friends have joined using your code."),
        FAQItem(question: "Can I track multiple portfolios?", answer: "Yes! You can create multiple portfolios to organize your investments. Each portfolio can hold crypto, stocks, commodities, and real estate. Navigate to the Portfolio tab to create and manage your portfolios."),
        FAQItem(question: "What are Risk Coins?", answer: "Risk Coins let you choose which assets display risk level widgets on your Home Screen. BTC is available for all users, and Pro subscribers can add additional coins like ETH. Go to Settings > Risk Coins to customize."),
        FAQItem(question: "How do I request a new feature?", answer: "Go to Settings > Request a Feature. Describe your idea with a title, category, and detailed description. Our team reviews all requests and considers them for future updates."),
        FAQItem(question: "Is my data secure?", answer: "Yes, we use industry-standard encryption and security practices including SSL pinning and Keychain storage. Your data is stored securely and we never share your personal information with third parties."),
        FAQItem(question: "How do I manage my notifications?", answer: "Go to Settings > Notification Settings. You can individually enable or disable push notifications for DCA reminders, market alerts, sentiment shifts, and insights. You can also control which types of email notifications you receive."),
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
