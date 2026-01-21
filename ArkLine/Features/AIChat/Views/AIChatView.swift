import SwiftUI

struct AIChatView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @State private var viewModel = AIChatViewModel()

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient background with subtle blue glow
                MeshGradientBackground()

                // Content
                VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.messages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                            }

                            if viewModel.isTyping {
                                TypingIndicator()
                                    .id("typing")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: viewModel.isTyping) { _, isTyping in
                        if isTyping {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                }

                // Input Bar
                ChatInputBar(
                    text: $viewModel.inputText,
                    isTyping: viewModel.isTyping,
                    onSend: {
                        Task {
                            await viewModel.sendMessage()
                        }
                    }
                )
            }
            }
            .navigationTitle("AI Assistant")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: ChatHistoryView(viewModel: viewModel)) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(AppColors.accent)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.createNewSession() }) {
                        Image(systemName: "plus")
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
            #endif
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation {
            if viewModel.isTyping {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if let lastId = viewModel.messages.last?.id {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }
}

// MARK: - Chat Bubble
struct ChatBubble: View {
    @Environment(\.colorScheme) var colorScheme
    let message: AIChatMessage

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(AppFonts.body14)
                    .foregroundColor(isUser ? .white : AppColors.textPrimary(colorScheme))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .if(isUser) { view in
                        view.background(AppColors.accent)
                            .cornerRadius(16)
                    }
                    .if(!isUser) { view in
                        view.glassCard(cornerRadius: 16)
                    }

                Text(message.createdAt.displayTime)
                    .font(AppFonts.footnote10)
                    .foregroundColor(AppColors.textSecondary)
            }

            if !isUser { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Typing Indicator
struct TypingIndicator: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var animationPhase = 0

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(AppColors.textSecondary)
                        .frame(width: 8, height: 8)
                        .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                        .animation(
                            .easeInOut(duration: 0.5)
                                .repeatForever()
                                .delay(Double(index) * 0.15),
                            value: animationPhase
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassCard(cornerRadius: 16)

            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }
}

// MARK: - Chat Input Bar
struct ChatInputBar: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var text: String
    let isTyping: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("Ask anything...", text: $text, axis: .vertical)
                .font(AppFonts.body14)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassCard(cornerRadius: 24)
                .lineLimit(1...5)
                .disabled(isTyping)

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(text.isEmpty || isTyping ? AppColors.textSecondary : AppColors.accent)
            }
            .disabled(text.isEmpty || isTyping)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassCard(cornerRadius: 0)
        .padding(.bottom, 80)
    }
}

// MARK: - Chat History View
struct ChatHistoryView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @Bindable var viewModel: AIChatViewModel

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()
            List {
                ForEach(viewModel.sortedSessions) { session in
                    Button(action: { viewModel.selectSession(session) }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.title ?? "New Chat")
                                    .font(AppFonts.body14Medium)
                                    .foregroundColor(AppColors.textPrimary(colorScheme))

                                Text(session.updatedAt.relativeTime)
                                    .font(AppFonts.caption12)
                                    .foregroundColor(AppColors.textSecondary)
                            }

                            Spacer()

                            if viewModel.currentSession?.id == session.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewModel.deleteSession(session)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .glassListRowBackground()
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.sidebar)
            #endif
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Chat History")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    AIChatView()
}
