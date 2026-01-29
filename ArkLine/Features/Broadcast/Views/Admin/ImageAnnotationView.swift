import SwiftUI
import PhotosUI

// MARK: - Image Annotation View

/// View for annotating images with drawing tools.
/// Supports arrows, lines, circles, rectangles, and text annotations.
struct ImageAnnotationView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @Binding var images: [BroadcastImage]

    @State private var selectedImage: UIImage?
    @State private var currentAnnotations: [ImageAnnotation] = []
    @State private var selectedTool: AnnotationType = .arrow
    @State private var selectedColor: Color = .red
    @State private var strokeWidth: CGFloat = 3.0
    @State private var currentPath: [CGPoint] = []
    @State private var textInput: String = ""
    @State private var showingTextInput = false
    @State private var textPosition: CGPoint = .zero
    @State private var showingPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?

    private let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .white, .black]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let image = selectedImage {
                    // Canvas with image
                    annotationCanvas(image: image)

                    // Tool bar
                    toolBar
                } else {
                    // Image picker
                    imagePickerView
                }
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Annotate Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if selectedImage != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            saveAnnotatedImage()
                        }
                    }
                }
            }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $photoPickerItem, matching: .images)
            .onChange(of: photoPickerItem) { _, newValue in
                loadImage(from: newValue)
            }
            .alert("Add Text", isPresented: $showingTextInput) {
                TextField("Enter text", text: $textInput)
                Button("Cancel", role: .cancel) {
                    textInput = ""
                }
                Button("Add") {
                    addTextAnnotation()
                }
            }
        }
    }

    // MARK: - Image Picker View

    private var imagePickerView: some View {
        VStack(spacing: ArkSpacing.xl) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundColor(AppColors.textTertiary)

            Text("Select an Image to Annotate")
                .font(ArkFonts.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Text("Import a chart or screenshot to draw on")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)

            Button {
                showingPhotoPicker = true
            } label: {
                HStack {
                    Image(systemName: "photo.fill")
                    Text("Choose from Library")
                }
                .font(ArkFonts.bodySemibold)
                .foregroundColor(.white)
                .padding(.horizontal, ArkSpacing.lg)
                .padding(.vertical, ArkSpacing.sm)
                .background(AppColors.accent)
                .cornerRadius(ArkSpacing.sm)
            }

            Spacer()
        }
        .padding(ArkSpacing.md)
    }

    // MARK: - Annotation Canvas

    private func annotationCanvas(image: UIImage) -> some View {
        GeometryReader { geometry in
            let imageSize = calculateImageSize(for: image, in: geometry.size)

            ZStack {
                // Base image
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: imageSize.width, height: imageSize.height)

                // Existing annotations
                Canvas { context, size in
                    for annotation in currentAnnotations {
                        drawAnnotation(annotation, in: &context, size: size, imageSize: imageSize)
                    }

                    // Current drawing path
                    if !currentPath.isEmpty {
                        drawCurrentPath(in: &context, size: size, imageSize: imageSize)
                    }
                }
                .frame(width: imageSize.width, height: imageSize.height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleDrag(value, imageSize: imageSize, containerSize: geometry.size)
                    }
                    .onEnded { value in
                        handleDragEnd(value, imageSize: imageSize, containerSize: geometry.size)
                    }
            )
        }
    }

    private func calculateImageSize(for image: UIImage, in containerSize: CGSize) -> CGSize {
        let imageAspect = image.size.width / image.size.height
        let containerAspect = containerSize.width / containerSize.height

        if imageAspect > containerAspect {
            let width = containerSize.width
            let height = width / imageAspect
            return CGSize(width: width, height: height)
        } else {
            let height = containerSize.height
            let width = height * imageAspect
            return CGSize(width: width, height: height)
        }
    }

    // MARK: - Drawing Methods

    private func drawAnnotation(_ annotation: ImageAnnotation, in context: inout GraphicsContext, size: CGSize, imageSize: CGSize) {
        let color = Color(hex: annotation.color)

        switch annotation.type {
        case .arrow:
            drawArrow(points: annotation.points, color: color, width: annotation.strokeWidth, in: &context)
        case .line:
            drawLine(points: annotation.points, color: color, width: annotation.strokeWidth, in: &context)
        case .circle:
            drawCircle(points: annotation.points, color: color, width: annotation.strokeWidth, in: &context)
        case .rectangle:
            drawRectangle(points: annotation.points, color: color, width: annotation.strokeWidth, in: &context)
        case .freehand:
            drawFreehand(points: annotation.points, color: color, width: annotation.strokeWidth, in: &context)
        case .text:
            if let text = annotation.text, let firstPoint = annotation.points.first {
                drawText(text, at: firstPoint, color: color, in: &context)
            }
        }
    }

    private func drawCurrentPath(in context: inout GraphicsContext, size: CGSize, imageSize: CGSize) {
        guard currentPath.count >= 1 else { return }

        switch selectedTool {
        case .arrow:
            drawArrow(points: currentPath, color: selectedColor, width: strokeWidth, in: &context)
        case .line:
            drawLine(points: currentPath, color: selectedColor, width: strokeWidth, in: &context)
        case .circle:
            drawCircle(points: currentPath, color: selectedColor, width: strokeWidth, in: &context)
        case .rectangle:
            drawRectangle(points: currentPath, color: selectedColor, width: strokeWidth, in: &context)
        case .freehand:
            drawFreehand(points: currentPath, color: selectedColor, width: strokeWidth, in: &context)
        case .text:
            break
        }
    }

    private func drawArrow(points: [CGPoint], color: Color, width: CGFloat, in context: inout GraphicsContext) {
        guard let start = points.first, let end = points.last, points.count >= 2 else { return }

        // Draw line
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        context.stroke(path, with: .color(color), lineWidth: width)

        // Draw arrowhead
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = 15
        let arrowAngle: CGFloat = .pi / 6

        var arrowPath = Path()
        arrowPath.move(to: end)
        arrowPath.addLine(to: CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        ))
        arrowPath.move(to: end)
        arrowPath.addLine(to: CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        ))
        context.stroke(arrowPath, with: .color(color), lineWidth: width)
    }

    private func drawLine(points: [CGPoint], color: Color, width: CGFloat, in context: inout GraphicsContext) {
        guard let start = points.first, let end = points.last, points.count >= 2 else { return }
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        context.stroke(path, with: .color(color), lineWidth: width)
    }

    private func drawCircle(points: [CGPoint], color: Color, width: CGFloat, in context: inout GraphicsContext) {
        guard let start = points.first, let end = points.last, points.count >= 2 else { return }
        let center = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let radius = sqrt(pow(end.x - start.x, 2) + pow(end.y - start.y, 2)) / 2

        var path = Path()
        path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        context.stroke(path, with: .color(color), lineWidth: width)
    }

    private func drawRectangle(points: [CGPoint], color: Color, width: CGFloat, in context: inout GraphicsContext) {
        guard let start = points.first, let end = points.last, points.count >= 2 else { return }
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )

        var path = Path()
        path.addRect(rect)
        context.stroke(path, with: .color(color), lineWidth: width)
    }

    private func drawFreehand(points: [CGPoint], color: Color, width: CGFloat, in context: inout GraphicsContext) {
        guard let first = points.first, points.count >= 2 else { return }
        var path = Path()
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    private func drawText(_ text: String, at point: CGPoint, color: Color, in context: inout GraphicsContext) {
        let resolvedText = context.resolve(Text(text).font(.system(size: 16, weight: .bold)).foregroundColor(color))
        context.draw(resolvedText, at: point, anchor: .leading)
    }

    // MARK: - Gesture Handling

    private func handleDrag(_ value: DragGesture.Value, imageSize: CGSize, containerSize: CGSize) {
        let offset = CGPoint(
            x: (containerSize.width - imageSize.width) / 2,
            y: (containerSize.height - imageSize.height) / 2
        )

        let point = CGPoint(
            x: value.location.x - offset.x,
            y: value.location.y - offset.y
        )

        // Clamp to image bounds
        let clampedPoint = CGPoint(
            x: max(0, min(imageSize.width, point.x)),
            y: max(0, min(imageSize.height, point.y))
        )

        if selectedTool == .freehand {
            currentPath.append(clampedPoint)
        } else if currentPath.isEmpty {
            currentPath = [clampedPoint]
        } else if let first = currentPath.first {
            currentPath = [first, clampedPoint]
        }
    }

    private func handleDragEnd(_ value: DragGesture.Value, imageSize: CGSize, containerSize: CGSize) {
        if selectedTool == .text {
            let offset = CGPoint(
                x: (containerSize.width - imageSize.width) / 2,
                y: (containerSize.height - imageSize.height) / 2
            )
            textPosition = CGPoint(
                x: value.location.x - offset.x,
                y: value.location.y - offset.y
            )
            showingTextInput = true
        } else if currentPath.count >= 2 {
            let annotation = ImageAnnotation(
                type: selectedTool,
                points: currentPath,
                color: selectedColor.toHex(),
                strokeWidth: strokeWidth
            )
            currentAnnotations.append(annotation)
        }
        currentPath = []
    }

    private func addTextAnnotation() {
        guard !textInput.isEmpty else { return }
        let annotation = ImageAnnotation(
            type: .text,
            points: [textPosition],
            color: selectedColor.toHex(),
            strokeWidth: strokeWidth,
            text: textInput
        )
        currentAnnotations.append(annotation)
        textInput = ""
    }

    // MARK: - Tool Bar

    private var toolBar: some View {
        VStack(spacing: ArkSpacing.sm) {
            // Tools
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ArkSpacing.sm) {
                    ForEach(AnnotationType.allCases, id: \.self) { tool in
                        toolButton(tool)
                    }

                    Divider()
                        .frame(height: 30)

                    // Undo button
                    Button {
                        if !currentAnnotations.isEmpty {
                            currentAnnotations.removeLast()
                        }
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.body)
                            .foregroundColor(currentAnnotations.isEmpty ? AppColors.textTertiary : AppColors.accent)
                    }
                    .disabled(currentAnnotations.isEmpty)

                    // Clear all
                    Button {
                        currentAnnotations.removeAll()
                    } label: {
                        Image(systemName: "trash")
                            .font(.body)
                            .foregroundColor(currentAnnotations.isEmpty ? AppColors.textTertiary : AppColors.error)
                    }
                    .disabled(currentAnnotations.isEmpty)
                }
                .padding(.horizontal, ArkSpacing.md)
            }

            // Colors
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ArkSpacing.sm) {
                    ForEach(colors, id: \.self) { color in
                        colorButton(color)
                    }

                    Divider()
                        .frame(height: 24)

                    // Stroke width
                    HStack(spacing: ArkSpacing.xs) {
                        Text("Size")
                            .font(ArkFonts.caption)
                            .foregroundColor(AppColors.textSecondary)

                        Slider(value: $strokeWidth, in: 1...10, step: 1)
                            .frame(width: 80)
                    }
                }
                .padding(.horizontal, ArkSpacing.md)
            }
        }
        .padding(.vertical, ArkSpacing.sm)
        .background(AppColors.cardBackground(colorScheme))
    }

    private func toolButton(_ tool: AnnotationType) -> some View {
        Button {
            selectedTool = tool
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tool.iconName)
                    .font(.body)
                Text(tool.displayName)
                    .font(.system(size: 10))
            }
            .foregroundColor(selectedTool == tool ? .white : AppColors.textPrimary(colorScheme))
            .frame(width: 50, height: 50)
            .background(selectedTool == tool ? AppColors.accent : AppColors.cardBackground(colorScheme))
            .cornerRadius(ArkSpacing.xs)
        }
    }

    private func colorButton(_ color: Color) -> some View {
        Button {
            selectedColor = color
        } label: {
            Circle()
                .fill(color)
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .stroke(selectedColor == color ? Color.white : Color.clear, lineWidth: 2)
                )
                .overlay(
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }

    // MARK: - Image Loading

    private func loadImage(from item: PhotosPickerItem?) {
        guard let item = item else { return }

        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                await MainActor.run {
                    selectedImage = uiImage
                    currentAnnotations = []
                }
            }
        }
    }

    // MARK: - Save

    private func saveAnnotatedImage() {
        guard selectedImage != nil else { return }

        // For now, just save the annotations without rendering
        // In production, you'd render the image with annotations to a new UIImage
        let broadcastImage = BroadcastImage(
            imageURL: URL(string: "local://temp")!, // Placeholder - would upload to Supabase
            annotations: currentAnnotations,
            caption: nil
        )

        images.append(broadcastImage)
        dismiss()
    }
}

// MARK: - Color Extension

extension Color {
    func toHex() -> String {
        guard let components = UIColor(self).cgColor.components else { return "#FF0000" }

        let r = components.count > 0 ? components[0] : 0
        let g = components.count > 1 ? components[1] : 0
        let b = components.count > 2 ? components[2] : 0

        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// MARK: - Preview

#Preview {
    ImageAnnotationView(images: .constant([]))
}
