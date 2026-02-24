import SwiftUI
import LinkPresentation

// MARK: - Reference Picker Tab

private enum ReferencePickerTab: String, CaseIterable {
    case indicators = "Indicators"
    case assets = "Assets"
    case links = "Links"
}

// MARK: - App Reference Picker View

/// View for selecting app sections, assets, or external links to reference in a broadcast.
struct AppReferencePickerView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @Binding var selectedReferences: [AppReference]

    @State private var selectedTab: ReferencePickerTab = .indicators
    @State private var searchText = ""
    @State private var editingReference: AppReference?
    @State private var showingNoteEditor = false

    // Asset search state
    @State private var assetSearchQuery = ""
    @State private var cryptoResults: [CryptoAsset] = []
    @State private var stockResults: [StockSearchResult] = []
    @State private var isSearchingAssets = false

    // Link entry state
    @State private var linkURLText = ""
    @State private var fetchedLink: ExternalLink?
    @State private var isFetchingLink = false
    @State private var linkError: String?

    private let marketService: MarketServiceProtocol = ServiceContainer.shared.marketService

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented control
                Picker("Reference Type", selection: $selectedTab) {
                    ForEach(ReferencePickerTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, ArkSpacing.md)
                .padding(.vertical, ArkSpacing.sm)

                // Selected references (always visible)
                if !selectedReferences.isEmpty {
                    selectedReferencesHeader
                }

                // Tab content
                switch selectedTab {
                case .indicators:
                    indicatorsTab
                case .assets:
                    assetsTab
                case .links:
                    linksTab
                }
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("App References")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingNoteEditor) {
                if let reference = editingReference {
                    NoteEditorSheet(
                        reference: reference,
                        onSave: { updatedReference in
                            if let index = selectedReferences.firstIndex(where: { $0.id == updatedReference.id }) {
                                selectedReferences[index] = updatedReference
                            }
                            editingReference = nil
                        }
                    )
                }
            }
        }
    }

    // MARK: - Selected References Header

    private var selectedReferencesHeader: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            HStack {
                Text("Selected (\(selectedReferences.count))")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
            }
            .padding(.horizontal, ArkSpacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ArkSpacing.xs) {
                    ForEach(selectedReferences) { reference in
                        HStack(spacing: ArkSpacing.xxs) {
                            Image(systemName: reference.iconName)
                                .font(.caption2)
                            Text(reference.displayName)
                                .font(ArkFonts.caption)
                                .lineLimit(1)
                            Button {
                                selectedReferences.removeAll { $0.id == reference.id }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                            }
                        }
                        .foregroundColor(AppColors.accent)
                        .padding(.horizontal, ArkSpacing.sm)
                        .padding(.vertical, ArkSpacing.xxs)
                        .background(AppColors.accent.opacity(0.1))
                        .cornerRadius(ArkSpacing.xs)
                    }
                }
                .padding(.horizontal, ArkSpacing.md)
            }
        }
        .padding(.vertical, ArkSpacing.xs)
        .background(AppColors.cardBackground(colorScheme))
    }

    // MARK: - Indicators Tab

    private var indicatorsTab: some View {
        List {
            Section {
                ForEach(filteredSections, id: \.self) { section in
                    availableSectionRow(section)
                }
            } header: {
                Text("Macro Indicators")
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: "Search indicators")
    }

    private var filteredSections: [AppSection] {
        let selectedSections = Set(selectedReferences.compactMap(\.section))
        let availableSections = AppSection.allCases.filter { !selectedSections.contains($0) }

        if searchText.isEmpty {
            return availableSections
        }

        return availableSections.filter { section in
            section.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func availableSectionRow(_ section: AppSection) -> some View {
        Button {
            addReference(for: section)
        } label: {
            HStack(spacing: ArkSpacing.md) {
                Image(systemName: section.iconName)
                    .font(.title3)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: ArkSpacing.xxs) {
                    Text(section.displayName)
                        .font(ArkFonts.body)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text(sectionDescription(section))
                        .font(ArkFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "plus.circle")
                    .foregroundColor(AppColors.accent)
            }
            .padding(.vertical, ArkSpacing.xxs)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Assets Tab

    private var assetsTab: some View {
        List {
            // Quick picks
            Section {
                ForEach(quickPickAssets, id: \.symbol) { asset in
                    assetRow(asset)
                }
            } header: {
                Text("Quick Add")
            }

            // Search
            Section {
                HStack(spacing: ArkSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppColors.textSecondary)

                    TextField("Search crypto, stocks...", text: $assetSearchQuery)
                        .font(ArkFonts.body)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit {
                            Task { await searchAssets() }
                        }

                    if isSearchingAssets {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }

                if !assetSearchQuery.isEmpty {
                    Button {
                        Task { await searchAssets() }
                    } label: {
                        HStack {
                            Text("Search for \"\(assetSearchQuery)\"")
                                .font(ArkFonts.body)
                            Spacer()
                            Image(systemName: "arrow.right.circle")
                        }
                        .foregroundColor(AppColors.accent)
                    }
                }
            } header: {
                Text("Search Assets")
            }

            // Crypto results
            if !cryptoResults.isEmpty {
                Section {
                    ForEach(cryptoResults) { crypto in
                        Button {
                            addAssetReference(
                                symbol: crypto.symbol.uppercased(),
                                assetType: .crypto,
                                displayName: crypto.name,
                                coinGeckoId: crypto.id
                            )
                        } label: {
                            assetResultRow(
                                symbol: crypto.symbol.uppercased(),
                                name: crypto.name,
                                icon: "bitcoinsign.circle",
                                type: "Crypto"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Crypto")
                }
            }

            // Stock results
            if !stockResults.isEmpty {
                Section {
                    ForEach(stockResults) { stock in
                        Button {
                            addAssetReference(
                                symbol: stock.symbol,
                                assetType: .stock,
                                displayName: stock.name,
                                coinGeckoId: nil
                            )
                        } label: {
                            assetResultRow(
                                symbol: stock.symbol,
                                name: stock.name,
                                icon: "chart.line.uptrend.xyaxis",
                                type: stock.exchange ?? "Stock"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Stocks")
                }
            }

            // Commodities (always shown)
            Section {
                ForEach(PreciousMetal.allCases, id: \.rawValue) { metal in
                    Button {
                        addAssetReference(
                            symbol: metal.rawValue,
                            assetType: .commodity,
                            displayName: metal.name,
                            coinGeckoId: nil
                        )
                    } label: {
                        assetResultRow(
                            symbol: metal.rawValue,
                            name: metal.name,
                            icon: "scalemass",
                            type: "Commodity"
                        )
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Commodities")
            }
        }
        .listStyle(.insetGrouped)
    }

    private var quickPickAssets: [AssetReference] {
        [
            AssetReference(symbol: "BTC", assetType: .crypto, displayName: "Bitcoin", coinGeckoId: "bitcoin"),
            AssetReference(symbol: "ETH", assetType: .crypto, displayName: "Ethereum", coinGeckoId: "ethereum"),
            AssetReference(symbol: "SOL", assetType: .crypto, displayName: "Solana", coinGeckoId: "solana"),
        ]
    }

    private func assetRow(_ asset: AssetReference) -> some View {
        Button {
            addAssetReference(
                symbol: asset.symbol,
                assetType: asset.assetType,
                displayName: asset.displayName,
                coinGeckoId: asset.coinGeckoId
            )
        } label: {
            HStack(spacing: ArkSpacing.md) {
                Image(systemName: asset.iconName)
                    .font(.title3)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: ArkSpacing.xxs) {
                    Text(asset.displayName)
                        .font(ArkFonts.body)
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                    Text(asset.symbol)
                        .font(ArkFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Image(systemName: "plus.circle")
                    .foregroundColor(AppColors.accent)
            }
            .padding(.vertical, ArkSpacing.xxs)
        }
        .buttonStyle(.plain)
    }

    private func assetResultRow(symbol: String, name: String, icon: String, type: String) -> some View {
        HStack(spacing: ArkSpacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: ArkSpacing.xxs) {
                Text(name)
                    .font(ArkFonts.body)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                    .lineLimit(1)

                HStack(spacing: ArkSpacing.xs) {
                    Text(symbol)
                        .font(ArkFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                    Text(type)
                        .font(ArkFonts.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            Spacer()

            Image(systemName: "plus.circle")
                .foregroundColor(AppColors.accent)
        }
        .padding(.vertical, ArkSpacing.xxs)
    }

    private func searchAssets() async {
        let query = assetSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        isSearchingAssets = true
        defer { isSearchingAssets = false }

        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                do {
                    cryptoResults = try await marketService.searchCrypto(query: query)
                } catch {
                    cryptoResults = []
                }
            }
            group.addTask { @MainActor in
                do {
                    stockResults = try await marketService.searchStocks(query: query)
                } catch {
                    stockResults = []
                }
            }
        }
    }

    // MARK: - Links Tab

    private var linksTab: some View {
        List {
            Section {
                HStack(spacing: ArkSpacing.sm) {
                    Image(systemName: "link")
                        .foregroundColor(AppColors.textSecondary)

                    TextField("https://...", text: $linkURLText)
                        .font(ArkFonts.body)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    if !linkURLText.isEmpty {
                        Button {
                            linkURLText = ""
                            fetchedLink = nil
                            linkError = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !linkURLText.isEmpty {
                    Button {
                        Task { await fetchLinkMetadata() }
                    } label: {
                        HStack {
                            if isFetchingLink {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Fetching preview...")
                                    .font(ArkFonts.body)
                                    .foregroundColor(AppColors.textSecondary)
                            } else {
                                Image(systemName: "arrow.down.circle")
                                Text("Fetch Preview")
                                    .font(ArkFonts.body)
                            }
                            Spacer()
                        }
                        .foregroundColor(AppColors.accent)
                    }
                    .disabled(isFetchingLink || parsedLinkURL == nil)
                }

                if let error = linkError {
                    Text(error)
                        .font(ArkFonts.caption)
                        .foregroundColor(AppColors.error)
                }
            } header: {
                Text("Paste a URL")
            }

            // Preview
            if let link = fetchedLink {
                Section {
                    VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                        ExternalLinkPreviewCard(link: link)

                        Button {
                            let reference = AppReference(externalLink: link)
                            selectedReferences.append(reference)
                            // Reset
                            linkURLText = ""
                            fetchedLink = nil
                            linkError = nil
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                Text("Add to Broadcast")
                                    .font(ArkFonts.bodySemibold)
                                Spacer()
                            }
                            .foregroundColor(.white)
                            .padding(ArkSpacing.sm)
                            .background(AppColors.accent)
                            .cornerRadius(ArkSpacing.sm)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Preview")
                }
            }

            // Quick add without preview
            if let url = parsedLinkURL, fetchedLink == nil {
                Section {
                    Button {
                        let link = ExternalLink(
                            url: url,
                            title: nil,
                            description: nil,
                            imageURL: nil,
                            domain: url.host
                        )
                        let reference = AppReference(externalLink: link)
                        selectedReferences.append(reference)
                        linkURLText = ""
                        linkError = nil
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add without preview")
                                .font(ArkFonts.body)
                            Spacer()
                        }
                        .foregroundColor(AppColors.accent)
                    }
                } header: {
                    Text("Quick Add")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var parsedLinkURL: URL? {
        let trimmed = linkURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }
        return url
    }

    @MainActor
    private func fetchLinkMetadata() async {
        guard let url = parsedLinkURL else {
            linkError = "Enter a valid URL starting with https://"
            return
        }

        isFetchingLink = true
        linkError = nil
        defer { isFetchingLink = false }

        let provider = LPMetadataProvider()
        do {
            let metadata = try await provider.startFetchingMetadata(for: url)
            fetchedLink = ExternalLink(
                url: url,
                title: metadata.title,
                description: nil,
                imageURL: nil,
                domain: url.host
            )
        } catch {
            // Still allow adding the link, just without metadata
            fetchedLink = ExternalLink(
                url: url,
                title: nil,
                description: nil,
                imageURL: nil,
                domain: url.host
            )
        }
    }

    // MARK: - Actions

    private func addReference(for section: AppSection) {
        let reference = AppReference(section: section)
        selectedReferences.append(reference)
    }

    private func addAssetReference(symbol: String, assetType: AssetType, displayName: String, coinGeckoId: String?) {
        // Don't add duplicates
        let alreadyAdded = selectedReferences.contains {
            $0.assetReference?.symbol == symbol && $0.assetReference?.assetType == assetType
        }
        guard !alreadyAdded else { return }

        let assetRef = AssetReference(
            symbol: symbol,
            assetType: assetType,
            displayName: displayName,
            coinGeckoId: coinGeckoId
        )
        selectedReferences.append(AppReference(assetReference: assetRef))
    }

    private func deleteReferences(at offsets: IndexSet) {
        selectedReferences.remove(atOffsets: offsets)
    }

    // MARK: - Section Descriptions

    private func sectionDescription(_ section: AppSection) -> String {
        switch section {
        case .vix: return "Market volatility indicator"
        case .dxy: return "US Dollar strength index"
        case .m2: return "Money supply & liquidity"
        case .bitcoinRisk: return "Risk level analysis for BTC"
        case .upcomingEvents: return "Economic calendar & events"
        case .fearGreed: return "Market sentiment gauge"
        case .sentiment: return "Overall market mood"
        case .rainbowChart: return "Long-term BTC price bands"
        case .technicalAnalysis: return "Charts & technical indicators"
        case .portfolioShowcase: return "Portfolio comparison showcase"
        }
    }
}

// MARK: - Note Editor Sheet

private struct NoteEditorSheet: View {
    let reference: AppReference
    let onSave: (AppReference) -> Void

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var noteText: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: ArkSpacing.lg) {
                // Reference info
                HStack(spacing: ArkSpacing.md) {
                    Image(systemName: reference.iconName)
                        .font(.title2)
                        .foregroundColor(AppColors.accent)

                    Text(reference.displayName)
                        .font(ArkFonts.headline)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Spacer()
                }
                .padding(ArkSpacing.md)
                .background(AppColors.cardBackground(colorScheme))
                .cornerRadius(ArkSpacing.sm)

                // Note field
                VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                    Text("Note (optional)")
                        .font(ArkFonts.caption)
                        .foregroundColor(AppColors.textSecondary)

                    TextField("Add context about this reference...", text: $noteText, axis: .vertical)
                        .font(ArkFonts.body)
                        .lineLimit(3...6)
                        .padding(ArkSpacing.md)
                        .background(AppColors.cardBackground(colorScheme))
                        .cornerRadius(ArkSpacing.sm)
                }

                Spacer()
            }
            .padding(ArkSpacing.md)
            .background(AppColors.background(colorScheme))
            .navigationTitle("Edit Reference")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = reference
                        updated.note = noteText.isEmpty ? nil : noteText
                        onSave(updated)
                        dismiss()
                    }
                }
            }
            .onAppear {
                noteText = reference.note ?? ""
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AppReferencePickerView(selectedReferences: .constant([]))
}
