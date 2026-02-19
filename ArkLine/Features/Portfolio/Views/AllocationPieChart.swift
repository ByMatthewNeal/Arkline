import SwiftUI

// MARK: - Allocation Pie Chart
struct AllocationPieChart: View {
    let allocations: [PortfolioAllocation]
    let colorScheme: ColorScheme

    @State private var animationProgress: CGFloat = 0

    private var sliceData: [(allocation: PortfolioAllocation, startAngle: Angle, endAngle: Angle)] {
        var currentAngle = Angle(degrees: -90)
        return allocations.map { allocation in
            let start = currentAngle
            let end = currentAngle + Angle(degrees: allocation.percentage * 3.6)
            currentAngle = end
            return (allocation, start, end)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2 - 10

            ZStack {
                ForEach(sliceData, id: \.allocation.id) { slice in
                    let animatedEnd = Angle(
                        degrees: slice.startAngle.degrees + (slice.endAngle.degrees - slice.startAngle.degrees) * animationProgress
                    )
                    Path { path in
                        path.move(to: center)
                        path.addArc(center: center, radius: radius, startAngle: slice.startAngle, endAngle: animatedEnd, clockwise: false)
                    }
                    .fill(Color(hex: slice.allocation.color))
                }

                // Inner circle for donut effect
                Circle()
                    .fill(AppColors.background(colorScheme))
                    .frame(width: radius * 1.2, height: radius * 1.2)
                    .opacity(animationProgress)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animationProgress = 1
            }
        }
    }
}
