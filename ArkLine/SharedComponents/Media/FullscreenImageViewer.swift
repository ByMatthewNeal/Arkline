import SwiftUI
import Kingfisher

// MARK: - Fullscreen Image Viewer

struct FullscreenImageViewer: View {
    let images: [BroadcastImage]
    let initialIndex: Int
    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex: Int
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    init(images: [BroadcastImage], initialIndex: Int = 0) {
        self.images = images
        self.initialIndex = initialIndex
        _currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
                    ZoomableImageView(url: image.imageURL)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .automatic : .never))
            .indexViewStyle(.page(backgroundDisplayMode: .automatic))

            // Dismiss button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.8), .white.opacity(0.2))
                    }
                    .padding(ArkSpacing.md)
                }
                Spacer()
            }

            // Caption
            if let caption = images[safe: currentIndex]?.caption, !caption.isEmpty {
                VStack {
                    Spacer()
                    Text(caption)
                        .font(ArkFonts.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, ArkSpacing.md)
                        .padding(.vertical, ArkSpacing.sm)
                        .background(.ultraThinMaterial.opacity(0.6))
                        .cornerRadius(ArkSpacing.sm)
                        .padding(.bottom, 50)
                }
            }
        }
        .statusBarHidden()
    }
}

// MARK: - Zoomable Image View

private struct ZoomableImageView: View {
    let url: URL
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        KFImage(url)
            .resizable()
            .placeholder {
                ProgressView()
                    .tint(.white)
            }
            .fade(duration: 0.2)
            .aspectRatio(contentMode: .fit)
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        let newScale = lastScale * value.magnification
                        scale = min(max(newScale, 1.0), 5.0)
                    }
                    .onEnded { _ in
                        if scale <= 1.0 {
                            withAnimation(.spring(response: 0.3)) {
                                scale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            }
                        }
                        lastScale = scale
                    }
                    .simultaneously(with:
                        DragGesture()
                            .onChanged { value in
                                guard scale > 1.0 else { return }
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.3)) {
                    if scale > 1.0 {
                        scale = 1.0
                        lastScale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    } else {
                        scale = 3.0
                        lastScale = 3.0
                    }
                }
            }
    }
}

// MARK: - Safe Array Subscript

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
