import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - View Extensions
extension View {
    // MARK: - Conditional Modifiers
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    @ViewBuilder
    func ifLet<T, Content: View>(_ optional: T?, transform: (Self, T) -> Content) -> some View {
        if let value = optional {
            transform(self, value)
        } else {
            self
        }
    }

    // MARK: - Frame Helpers
    func frame(size: CGFloat) -> some View {
        frame(width: size, height: size)
    }

    func fillWidth(alignment: Alignment = .center) -> some View {
        frame(maxWidth: .infinity, alignment: alignment)
    }

    func fillHeight(alignment: Alignment = .center) -> some View {
        frame(maxHeight: .infinity, alignment: alignment)
    }

    func fill(alignment: Alignment = .center) -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }

    #if canImport(UIKit)
    // MARK: - Corner Radius with Specific Corners
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
    #endif

    // MARK: - Card Style
    func cardStyle(
        backgroundColor: Color = AppColors.cardBackground(.dark),
        cornerRadius: CGFloat = ArkSpacing.Radius.card,
        padding: CGFloat = ArkSpacing.Component.cardPadding
    ) -> some View {
        self
            .padding(padding)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
    }

    // MARK: - Gradient Background
    func gradientBackground(
        colors: [Color] = [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
        startPoint: UnitPoint = .topLeading,
        endPoint: UnitPoint = .bottomTrailing
    ) -> some View {
        background(
            LinearGradient(
                gradient: Gradient(colors: colors),
                startPoint: startPoint,
                endPoint: endPoint
            )
        )
    }

    // MARK: - Border Style
    func borderedStyle(
        color: Color = Color.white.opacity(0.1),
        width: CGFloat = 1,
        cornerRadius: CGFloat = ArkSpacing.Radius.md
    ) -> some View {
        self
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(color, lineWidth: width)
            )
    }

    // MARK: - Hidden Conditionally
    @ViewBuilder
    func hidden(_ shouldHide: Bool) -> some View {
        if shouldHide {
            hidden()
        } else {
            self
        }
    }

    // MARK: - On First Appear
    func onFirstAppear(perform action: @escaping () -> Void) -> some View {
        modifier(FirstAppearModifier(action: action))
    }

    // MARK: - Loading Overlay
    func loadingOverlay(isLoading: Bool) -> some View {
        overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.4)
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
        }
    }

    // MARK: - Shimmer Effect
    func shimmer(isLoading: Bool) -> some View {
        modifier(ShimmerModifier(isLoading: isLoading))
    }

    // MARK: - Navigation
    func embedInNavigationStack() -> some View {
        NavigationStack {
            self
        }
    }

    #if canImport(UIKit)
    // MARK: - Keyboard Dismissal
    func dismissKeyboardOnTap() -> some View {
        onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
    #endif

    // MARK: - Read Size
    func readSize(onChange: @escaping (CGSize) -> Void) -> some View {
        background(
            GeometryReader { geometryProxy in
                Color.clear
                    .preference(key: SizePreferenceKey.self, value: geometryProxy.size)
            }
        )
        .onPreferenceChange(SizePreferenceKey.self, perform: onChange)
    }

    // MARK: - Safe Area Insets
    func readSafeArea(onChange: @escaping (EdgeInsets) -> Void) -> some View {
        background(
            GeometryReader { geometryProxy in
                Color.clear
                    .preference(key: SafeAreaPreferenceKey.self, value: geometryProxy.safeAreaInsets)
            }
        )
        .onPreferenceChange(SafeAreaPreferenceKey.self, perform: onChange)
    }

    // MARK: - Scroll Offset
    func scrollOffset(_ offset: Binding<CGFloat>) -> some View {
        background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geometry.frame(in: .named("scroll")).minY
                )
            }
        )
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            offset.wrappedValue = value
        }
    }
}

#if canImport(UIKit)
// MARK: - Rounded Corner Shape
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
#endif

// MARK: - First Appear Modifier
struct FirstAppearModifier: ViewModifier {
    @State private var hasAppeared = false
    let action: () -> Void

    func body(content: Content) -> some View {
        content.onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            action()
        }
    }
}

// MARK: - Shimmer Modifier
struct ShimmerModifier: ViewModifier {
    let isLoading: Bool
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                if isLoading {
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0),
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .offset(x: phase)
                            .onAppear {
                                withAnimation(
                                    Animation.linear(duration: 1.5)
                                        .repeatForever(autoreverses: false)
                                ) {
                                    phase = geometry.size.width
                                }
                            }
                    }
                }
            }
            .mask(content)
    }
}

// MARK: - Preference Keys
struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct SafeAreaPreferenceKey: PreferenceKey {
    static var defaultValue: EdgeInsets = EdgeInsets()
    static func reduce(value: inout EdgeInsets, nextValue: () -> EdgeInsets) {
        value = nextValue()
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Animation Extensions
extension Animation {
    static let arkSpring = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let arkEaseOut = Animation.easeOut(duration: 0.3)
    static let arkEaseIn = Animation.easeIn(duration: 0.3)
    static let arkLinear = Animation.linear(duration: 0.3)
}

// MARK: - Staggered Card Appearance
struct CardAppearanceModifier: ViewModifier {
    let delay: Int
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            .onAppear {
                withAnimation(.easeOut(duration: 0.35).delay(Double(delay) * 0.06)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func cardAppearance(delay: Int) -> some View {
        modifier(CardAppearanceModifier(delay: delay))
    }
}

// MARK: - Press-Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.arkSpring, value: configuration.isPressed)
    }
}
