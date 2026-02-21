import SwiftUI

// MARK: - SMA Analysis Card
struct SMAAnalysisCard: View {
    let sma: SMAAnalysis
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            HStack {
                Text("Moving Averages")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Spacer()

                // Signal badge
                HStack(spacing: 6) {
                    Image(systemName: sma.overallSignal.icon)
                        .font(.subheadline)
                    Text(sma.overallSignal.rawValue)
                        .font(.subheadline.bold())
                }
                .foregroundColor(sma.overallSignal.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(sma.overallSignal.color.opacity(0.15))
                .clipShape(Capsule())
            }

            Divider()
                .background(AppColors.divider(colorScheme))

            // SMA rows
            VStack(spacing: ArkSpacing.sm) {
                SMARow(label: "21 SMA", data: sma.sma21, colorScheme: colorScheme)
                SMARow(label: "50 SMA", data: sma.sma50, colorScheme: colorScheme)
                SMARow(label: "200 SMA", data: sma.sma200, colorScheme: colorScheme)
            }

            // Golden/Death Cross indicator
            if sma.goldenCross || sma.deathCross {
                Divider()
                    .background(AppColors.divider(colorScheme))

                HStack {
                    Image(systemName: sma.goldenCross ? "sparkles" : "exclamationmark.triangle.fill")
                        .foregroundColor(sma.goldenCross ? AppColors.success : AppColors.error)

                    Text(sma.goldenCross ? "Golden Cross Active" : "Death Cross Active")
                        .font(.subheadline.bold())
                        .foregroundColor(sma.goldenCross ? AppColors.success : AppColors.error)

                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
    }
}

// MARK: - SMA Row
struct SMARow: View {
    let label: String
    let data: SMAData
    let colorScheme: ColorScheme

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            Text(data.displayValue)
                .font(.subheadline.monospacedDigit())
                .foregroundColor(AppColors.textPrimary(colorScheme))

            // Position indicator
            HStack(spacing: 4) {
                Image(systemName: data.priceAbove ? "arrow.up" : "arrow.down")
                    .font(.caption2)
                Text(data.distanceLabel)
                    .font(.caption.monospacedDigit())
            }
            .foregroundColor(data.priceAbove ? AppColors.success : AppColors.error)
            .frame(width: 80, alignment: .trailing)
        }
    }
}

// MARK: - Bollinger Bands Card
struct BollingerBandsCard: View {
    let bollinger: BollingerBandAnalysis
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            Text("Bollinger Bands")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Divider()
                .background(AppColors.divider(colorScheme))

            // Timeframe tabs
            VStack(spacing: ArkSpacing.md) {
                BollingerTimeframeRow(data: bollinger.daily, colorScheme: colorScheme)
                BollingerTimeframeRow(data: bollinger.weekly, colorScheme: colorScheme)
                BollingerTimeframeRow(data: bollinger.monthly, colorScheme: colorScheme)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
    }
}

// MARK: - Bollinger Timeframe Row
struct BollingerTimeframeRow: View {
    let data: BollingerBandData
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(data.timeframe.rawValue)
                    .font(.subheadline.bold())
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Spacer()

                // Position badge
                HStack(spacing: 4) {
                    Image(systemName: data.position.icon)
                        .font(.caption)
                    Text(data.position.description)
                        .font(.caption.bold())
                }
                .foregroundColor(data.position.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(data.position.color.opacity(0.15))
                .clipShape(Capsule())
            }

            // Visual band representation
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Band background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08))

                    // Price position indicator
                    let positionX = geo.size.width * min(1, max(0, data.percentB))
                    Circle()
                        .fill(data.position.color)
                        .frame(width: 12, height: 12)
                        .offset(x: positionX - 6)
                }
            }
            .frame(height: 12)

            // Band values
            HStack {
                Text("Lower: \(data.lowerBand.asCryptoPrice)")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                Text("Mid: \(data.middleBand.asCryptoPrice)")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                Text("Upper: \(data.upperBand.asCryptoPrice)")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }

            Text(data.position.signal)
                .font(.caption)
                .foregroundColor(data.position.color)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
        )
    }
}

// MARK: - Bull Market Support Bands Card
struct BullMarketBandsCard: View {
    let bands: BullMarketSupportBands
    let colorScheme: ColorScheme
    @State private var showInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            HStack {
                Text("Bull Market Bands")
                    .font(.subheadline.bold())
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Button {
                    showInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary.opacity(0.6))
                }
                .accessibilityLabel("Info about Bull Market Bands")

                Spacer()

                // Position badge
                HStack(spacing: 4) {
                    Image(systemName: bands.position.icon)
                        .font(.caption2)
                    Text(bands.position.rawValue)
                        .font(.caption.bold())
                }
                .foregroundColor(bands.position.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(bands.position.color.opacity(0.12))
                .clipShape(Capsule())
            }

            // Band indicators
            HStack(spacing: ArkSpacing.md) {
                BandIndicator(
                    label: "20W SMA",
                    value: bands.sma20Week,
                    isAbove: bands.aboveSMA,
                    percentFrom: bands.percentFromSMA,
                    colorScheme: colorScheme
                )
                BandIndicator(
                    label: "21W EMA",
                    value: bands.ema21Week,
                    isAbove: bands.aboveEMA,
                    percentFrom: bands.percentFromEMA,
                    colorScheme: colorScheme
                )
            }

            // Status description
            Text(bands.position.description)
                .font(.caption)
                .foregroundColor(bands.position.color)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .alert("Bull Market Support Bands", isPresented: $showInfo) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("The 20-week SMA and 21-week EMA act as support during bull markets. Price holding above these levels is bullish.")
        }
    }
}

// MARK: - Band Indicator
struct BandIndicator: View {
    let label: String
    let value: Double
    let isAbove: Bool
    let percentFrom: Double
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isAbove ? AppColors.success.opacity(0.15) : AppColors.error.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: isAbove ? "arrow.up" : "arrow.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isAbove ? AppColors.success : AppColors.error)
            }

            Text(label)
                .font(.caption2.bold())
                .foregroundColor(AppColors.textSecondary)

            Text(value.asCryptoPrice)
                .font(.caption2)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Text("\(percentFrom >= 0 ? "+" : "")\(String(format: "%.1f", percentFrom))%")
                .font(.caption2)
                .foregroundColor(isAbove ? AppColors.success : AppColors.error)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Key Levels Card (Simplified SMA)
struct KeyLevelsCard: View {
    let sma: SMAAnalysis
    let currentPrice: Double
    let colorScheme: ColorScheme
    @State private var showInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            HStack {
                Text("Key Levels")
                    .font(.subheadline.bold())
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Button {
                    showInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary.opacity(0.6))
                }
                .accessibilityLabel("Info about Key Levels")

                Spacer()

                // Signal badge
                HStack(spacing: 4) {
                    Image(systemName: sma.overallSignal.icon)
                        .font(.caption2)
                    Text(sma.overallSignal.rawValue)
                        .font(.caption.bold())
                }
                .foregroundColor(sma.overallSignal.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(sma.overallSignal.color.opacity(0.12))
                .clipShape(Capsule())
            }

            // Simplified SMA indicators
            HStack(spacing: ArkSpacing.md) {
                KeyLevelIndicator(
                    label: "21 MA",
                    isAbove: sma.above21SMA,
                    colorScheme: colorScheme
                )
                KeyLevelIndicator(
                    label: "50 MA",
                    isAbove: sma.above50SMA,
                    colorScheme: colorScheme
                )
                KeyLevelIndicator(
                    label: "200 MA",
                    isAbove: sma.above200SMA,
                    colorScheme: colorScheme
                )
            }

            // Golden/Death Cross alert
            if sma.goldenCross || sma.deathCross {
                HStack(spacing: 6) {
                    Image(systemName: sma.goldenCross ? "sparkles" : "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(sma.goldenCross ? "Golden Cross" : "Death Cross")
                        .font(.caption.bold())
                }
                .foregroundColor(sma.goldenCross ? AppColors.success : AppColors.error)
                .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .alert("Key Levels", isPresented: $showInfo) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("Shows if price is above or below key moving averages. A Golden Cross (bullish) or Death Cross (bearish) occurs when the 50 MA crosses the 200 MA.")
        }
    }
}

// MARK: - Key Level Indicator
struct KeyLevelIndicator: View {
    let label: String
    let isAbove: Bool
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isAbove ? AppColors.success.opacity(0.15) : AppColors.error.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: isAbove ? "arrow.up" : "arrow.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isAbove ? AppColors.success : AppColors.error)
            }

            Text(label)
                .font(.caption2)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Price Position Card (Simplified Bollinger)
struct PricePositionCard: View {
    let bollinger: BollingerBandData
    let colorScheme: ColorScheme
    @State private var showInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            HStack {
                Text("Price Position")
                    .font(.subheadline.bold())
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Button {
                    showInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary.opacity(0.6))
                }
                .accessibilityLabel("Info about Price Position")

                Spacer()

                // Position badge
                HStack(spacing: 4) {
                    Image(systemName: bollinger.position.icon)
                        .font(.caption2)
                    Text(bollinger.position.description)
                        .font(.caption.bold())
                }
                .foregroundColor(bollinger.position.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(bollinger.position.color.opacity(0.12))
                .clipShape(Capsule())
            }

            // Visual band representation
            VStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Band gradient background
                        LinearGradient(
                            colors: [
                                AppColors.success.opacity(0.3),
                                AppColors.warning.opacity(0.2),
                                AppColors.error.opacity(0.3)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        // Price position indicator
                        let positionX = geo.size.width * min(1, max(0, bollinger.percentB))
                        Circle()
                            .fill(Color.white)
                            .frame(width: 14, height: 14)
                            .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                            .overlay(
                                Circle()
                                    .fill(bollinger.position.color)
                                    .frame(width: 8, height: 8)
                            )
                            .offset(x: positionX - 7)
                    }
                }
                .frame(height: 20)

                // Labels
                HStack {
                    Text("Oversold")
                        .font(.caption2)
                        .foregroundColor(AppColors.success)

                    Spacer()

                    Text("Fair Value")
                        .font(.caption2)
                        .foregroundColor(AppColors.warning)

                    Spacer()

                    Text("Overbought")
                        .font(.caption2)
                        .foregroundColor(AppColors.error)
                }
            }

            // Signal text
            Text(bollinger.position.signal)
                .font(.caption)
                .foregroundColor(bollinger.position.color)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .alert("Price Position", isPresented: $showInfo) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("Uses Bollinger Bands to show if price is stretched. Near the lower band suggests oversold, near the upper band suggests overbought.")
        }
    }
}
