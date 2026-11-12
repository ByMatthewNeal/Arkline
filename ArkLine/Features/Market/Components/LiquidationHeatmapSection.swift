import SwiftUI

// MARK: - Color ramp (two-tone: blue below price, warm above)
private let heatBG = (14.0, 14.0, 18.0)
private let heatBelow: [(Double, Double, Double)] = [heatBG, (22, 34, 78), (51, 105, 255), (127, 176, 255)]
private let heatAbove: [(Double, Double, Double)] = [heatBG, (90, 30, 42), (224, 83, 58), (255, 200, 97)]

private func lerp(_ a: Double, _ b: Double, _ f: Double) -> Double { a + (b - a) * f }
private func rampColor(_ stops: [(Double, Double, Double)], _ t: Double) -> Color {
    let x = max(0, min(1, t)) * Double(stops.count - 1)
    let i = min(stops.count - 2, Int(x))
    let f = x - Double(i)
    let r = lerp(stops[i].0, stops[i + 1].0, f)
    let g = lerp(stops[i].1, stops[i + 1].1, f)
    let b = lerp(stops[i].2, stops[i + 1].2, f)
    return Color(red: r / 255, green: g / 255, blue: b / 255)
}

private func fmtK(_ v: Double) -> String {
    v >= 1000 ? String(format: "$%.1fk", v / 1000) : String(format: "$%.0f", v)
}

// MARK: - Heatmap Canvas
struct LiquidationHeatmapCanvas: View {
    let data: LiquidationHeatmapData
    var showAxes: Bool = true

    var body: some View {
        Canvas { ctx, size in
            let padL: CGFloat = showAxes ? 46 : 0
            let padB: CGFloat = 0
            let plotW = size.width - padL
            let plotH = size.height - padB
            let grid = data.grid
            let B = grid.count
            let D = grid.first?.count ?? 0
            guard B > 0, D > 0, plotW > 0, plotH > 0 else { return }
            let pmin = data.priceMin, pmax = data.priceMax, cur = data.currentPrice
            guard pmax > pmin else { return }

            // contrast: gamma + clip near 96th percentile
            var vals: [Double] = []
            for row in grid { for v in row where v > 0 { vals.append(pow(Double(v) / 1000, 0.6)) } }
            vals.sort()
            let vmax = vals.isEmpty ? 1 : vals[min(vals.count - 1, Int(Double(vals.count) * 0.96))]
            let safeVmax = vmax > 0 ? vmax : 1

            let cellW = plotW / CGFloat(D)
            let cellH = plotH / CGFloat(B)
            for b in 0..<B {
                let below = data.prices[b] < cur
                let y = plotH - CGFloat(b + 1) * cellH
                let stops = below ? heatBelow : heatAbove
                for t in 0..<D {
                    let v = grid[b][t]
                    if v <= 0 { continue }
                    let tt = min(1, pow(Double(v) / 1000, 0.6) / safeVmax)
                    let rect = CGRect(x: padL + CGFloat(t) * cellW, y: y, width: cellW + 0.6, height: cellH + 0.6)
                    ctx.fill(Path(rect), with: .color(rampColor(stops, tt)))
                }
            }

            func yOf(_ p: Double) -> CGFloat { plotH - CGFloat((p - pmin) / (pmax - pmin)) * plotH }

            // price line
            if data.closes.count == D {
                var path = Path()
                for t in 0..<D {
                    let x = padL + (CGFloat(t) + 0.5) * cellW
                    let yy = yOf(data.closes[t])
                    if t == 0 { path.move(to: CGPoint(x: x, y: yy)) } else { path.addLine(to: CGPoint(x: x, y: yy)) }
                }
                ctx.stroke(path, with: .color(.white.opacity(0.9)), lineWidth: 1.3)
            }

            // now line
            let ny = yOf(cur)
            var nl = Path()
            nl.move(to: CGPoint(x: padL, y: ny)); nl.addLine(to: CGPoint(x: size.width, y: ny))
            ctx.stroke(nl, with: .color(Color(red: 51 / 255, green: 105 / 255, blue: 255 / 255).opacity(0.9)),
                       style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

            if showAxes {
                for i in 0...5 {
                    let p = pmin + (pmax - pmin) * Double(i) / 5
                    ctx.draw(Text(fmtK(p)).font(.system(size: 9)).foregroundColor(Color(white: 0.43)),
                             at: CGPoint(x: padL - 5, y: yOf(p)), anchor: .trailing)
                }
                ctx.draw(Text("Now \(fmtK(cur))").font(.system(size: 9)).foregroundColor(Color(red: 0.56, green: 0.69, blue: 1.0)),
                         at: CGPoint(x: padL + 4, y: ny - 8), anchor: .leading)
            }
        }
        .background(Color(red: 14 / 255, green: 14 / 255, blue: 18 / 255))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Market Section (compact card)
struct LiquidationHeatmapSection: View {
    var refreshId: UUID = UUID()
    var embedded: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @State private var data: LiquidationHeatmapData?
    @State private var isLoading = true

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }
    private var cardBackground: Color { colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Liquidation Heatmap")
                    .font(.headline)
                    .foregroundColor(textPrimary)
                Spacer()
                if let d = data {
                    Text("BTC \(fmtK(d.currentPrice))")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            if isLoading {
                RoundedRectangle(cornerRadius: 10).fill(cardBackground.opacity(0.4))
                    .frame(height: 150).redacted(reason: .placeholder).shimmer(isLoading: true)
            } else if let d = data {
                NavigationLink {
                    LiquidationHeatmapDetailView()
                } label: {
                    VStack(spacing: 10) {
                        LiquidationHeatmapCanvas(data: d, showAxes: false)
                            .frame(height: 150)

                        if let top = d.clusters.first {
                            HStack(spacing: 4) {
                                Text("Largest cluster \(top.isBelow ? "below" : "above") at")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppColors.textSecondary)
                                Text(fmtK(top.price))
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(AppColors.textSecondary.opacity(0.6))
                            }
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 12).fill(cardBackground))
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Text("Heatmap unavailable right now.")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .background(RoundedRectangle(cornerRadius: 12).fill(cardBackground))
            }
        }
        .padding(.horizontal, embedded ? 0 : 16)
        .task(id: refreshId) { await load() }
    }

    private func load() async {
        let d = try? await ServiceContainer.shared.liquidationHeatmapService.fetch()
        data = d
        isLoading = false
    }
}

// MARK: - Detail View
struct LiquidationHeatmapDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var data: LiquidationHeatmapData?
    @State private var isLoading = true

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }
    private var cardBackground: Color { colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isLoading && data == nil {
                    HStack { Spacer(); ProgressView().padding(.vertical, 60); Spacer() }
                } else if let d = data {
                    LiquidationHeatmapCanvas(data: d, showAxes: true)
                        .frame(height: 300)
                        .padding(.horizontal)

                    legend

                    HStack(alignment: .top, spacing: 12) {
                        clusterColumn("Magnets below", d.clustersBelow, d.currentPrice, Color(red: 0.5, green: 0.69, blue: 1.0))
                        clusterColumn("Magnets above", d.clustersAbove, d.currentPrice, Color(red: 1.0, green: 0.67, blue: 0.35))
                    }
                    .padding(.horizontal)
                } else {
                    Text("Heatmap unavailable right now.")
                        .font(.subheadline).foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 40)
                }

                howItWorks
            }
            .padding(.top)
            .padding(.bottom, 100)
        }
        .navigationTitle("Liquidation Heatmap")
        .navigationBarTitleDisplayMode(.inline)
        .background(AppColors.background(colorScheme))
        .task { await load() }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(Color(red: 51 / 255, green: 105 / 255, blue: 255 / 255), "Below price")
            legendItem(Color(red: 224 / 255, green: 83 / 255, blue: 58 / 255), "Above price")
            legendItem(.white, "Price")
            Spacer()
        }
        .font(.system(size: 10))
        .padding(.horizontal)
    }

    private func legendItem(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1).fill(color).frame(width: 12, height: 3)
            Text(label).foregroundColor(AppColors.textSecondary)
        }
    }

    private func clusterColumn(_ title: String, _ clusters: [LiquidationCluster], _ cur: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold)).tracking(0.5)
                .foregroundColor(color)
            if clusters.isEmpty {
                Text("None standing.").font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
            } else {
                ForEach(clusters.prefix(4), id: \.price) { c in
                    HStack {
                        Text(fmtK(c.price))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(textPrimary)
                        Spacer()
                        Text(String(format: "%@%.1f%%", c.price >= cur ? "+" : "", (c.price - cur) / cur * 100))
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(cardBackground))
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How the Liquidation Heatmap Works")
                .font(.headline).foregroundColor(textPrimary)
            bullet("Bright bands mark price levels where leveraged positions would likely be liquidated. Blue sits below the current price, warm sits above.")
            bullet("A band persists until price trades through it, so a cluster still glowing has not been hit yet and can act as a magnet.")
            bullet("This is an estimate modeled from open positions and typical leverage, not exchange liquidation data. Guides, not guarantees. Source: Coinalyze.")
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(cardBackground))
        .padding(.horizontal)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•").foregroundColor(AppColors.accent)
            Text(text).font(.subheadline).foregroundColor(AppColors.textSecondary)
        }
    }

    private func load() async {
        let d = try? await ServiceContainer.shared.liquidationHeatmapService.fetch()
        data = d
        isLoading = false
    }
}
