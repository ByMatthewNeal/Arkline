import SwiftUI

// MARK: - Precious Metals Section
struct PreciousMetalsSection: View {
    let metalAssets: [MetalAsset]
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    // Only show Gold and Silver
    private var displayMetals: [MetalAsset] {
        metalAssets.filter { ["XAU", "XAG"].contains($0.symbol.uppercased()) }
    }

    var body: some View {
        if !displayMetals.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                // Section Header
                HStack {
                    Image(systemName: "cube.fill")
                        .foregroundColor(Color(hex: "F59E0B"))
                    Text("Precious Metals")
                        .font(.headline)
                        .foregroundColor(textPrimary)

                    Spacer()
                }
                .padding(.horizontal)

                // Metal Cards
                VStack(spacing: 12) {
                    ForEach(displayMetals) { metal in
                        PreciousMetalCard(metal: metal)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Precious Metal Card
struct PreciousMetalCard: View {
    let metal: MetalAsset
    @Environment(\.colorScheme) var colorScheme
    @State private var showingDetail = false

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }
    private var isPositive: Bool { metal.priceChangePercentage24h >= 0 }

    private var metalIcon: String {
        switch metal.symbol.uppercased() {
        case "XAU": return "Au"
        case "XAG": return "Ag"
        case "XPT": return "Pt"
        case "XPD": return "Pd"
        default: return String(metal.symbol.prefix(2))
        }
    }

    private var iconColors: [Color] {
        switch metal.symbol.uppercased() {
        case "XAU": return [Color(hex: "F59E0B"), Color(hex: "D97706")]
        case "XAG": return [Color(hex: "94A3B8"), Color(hex: "64748B")]
        default: return [Color(hex: "A78BFA"), Color(hex: "7C3AED")]
        }
    }

    var body: some View {
        Button(action: { showingDetail = true }) {
            HStack(spacing: 16) {
                // Metal Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: iconColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Text(metalIcon)
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                }

                // Name & Symbol
                VStack(alignment: .leading, spacing: 2) {
                    Text(metal.name)
                        .font(.headline)
                        .foregroundColor(textPrimary)

                    Text(metal.symbol.uppercased())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Price & Change
                VStack(alignment: .trailing, spacing: 4) {
                    Text(metal.currentPrice.asCurrency)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(textPrimary)

                    if metal.priceChange24h != 0 {
                        HStack(spacing: 4) {
                            Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                                .font(.system(size: 10, weight: .bold))
                            Text("\(isPositive ? "+" : "")\(metal.priceChangePercentage24h, specifier: "%.2f")%")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(isPositive ? AppColors.success : AppColors.error)
                    } else {
                        Text("per \(metal.unit)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            NavigationStack {
                MetalDetailView(asset: metal)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showingDetail = false }
                        }
                    }
            }
        }
    }
}
