import SwiftUI

struct TrendChannelFullscreenView: View {
    @Bindable var viewModel: TrendChannelViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                chart
                timeRangePicker
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            #if canImport(UIKit)
            AppDelegate.orientationLock = .allButUpsideDown
            #endif
        }
        .onDisappear {
            #if canImport(UIKit)
            AppDelegate.orientationLock = .portrait
            if let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
            }
            #endif
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.selectedIndex.displayName) Trend Channel")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                if let point = viewModel.selectedChannelPoint() {
                    selectedPointInfo(point)
                } else if let price = viewModel.currentPrice,
                          let zone = viewModel.channelData?.currentZone {
                    currentPriceInfo(price: price, zone: zone)
                } else {
                    Text("Drag to explore")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            Spacer()

            Button {
                #if canImport(UIKit)
                AppDelegate.orientationLock = .portrait
                if let windowScene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene }).first {
                    windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
                }
                #endif
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func selectedPointInfo(_ point: LogRegressionPoint) -> some View {
        HStack(spacing: 6) {
            Text(formatCurrency(point.close))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(point.zone.rawValue)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(point.zone.color)
            Text("·")
                .foregroundColor(.white.opacity(0.4))
            Text(formatDate(point.date))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private func currentPriceInfo(price: Double, zone: TrendChannelZone) -> some View {
        HStack(spacing: 6) {
            Text(formatCurrency(price))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(zone.rawValue)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(zone.color)
        }
    }

    // MARK: - Chart

    private var chart: some View {
        TrendChannelChart(
            channelData: viewModel.channelData,
            consolidationRanges: viewModel.consolidationRanges,
            selectedDate: $viewModel.selectedDate,
            isLoading: viewModel.isLoading
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Time Range Picker

    private var timeRangePicker: some View {
        HStack(spacing: 8) {
            ForEach(TrendChannelTimeRange.allCases) { range in
                Button {
                    Task { await viewModel.switchTimeRange(range) }
                } label: {
                    Text(range.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(
                            viewModel.selectedTimeRange == range
                                ? .white
                                : .white.opacity(0.5)
                        )
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(
                                    viewModel.selectedTimeRange == range
                                        ? AppColors.accent
                                        : Color.white.opacity(0.1)
                                )
                        )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Helpers

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if viewModel.selectedTimeRange == .fourHour {
            formatter.dateFormat = "MMM d, h:mm a"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
        }
        return formatter.string(from: date)
    }
}
