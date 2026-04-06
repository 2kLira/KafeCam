import SwiftUI

struct AvatarEditorView: View {
    let original: UIImage
    let onCancel: () -> Void
    let onSave: (UIImage) -> Void

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastDrag: CGSize = .zero

    private let frameSize: CGFloat = 300

    var body: some View {
        VStack(spacing: 16) {
            Text("Ajusta tu foto").font(.headline)

            ZStack {
                Color(.systemGray6)
                Image(uiImage: original)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(width: lastDrag.width + value.translation.width,
                                                height: lastDrag.height + value.translation.height)
                            }
                            .onEnded { _ in
                                lastDrag = offset
                            }
                    )
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = min(max(1.0, value), 4.0)
                            }
                    )
                    .frame(width: frameSize, height: frameSize)
                    .clipped()
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.8), lineWidth: 2)
                            .padding(2)
                    )
            }
            .frame(width: frameSize, height: frameSize)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 6)

            // Zoom slider
            HStack {
                Image(systemName: "minus.magnifyingglass")
                Slider(value: Binding(get: { Double(scale) }, set: { scale = CGFloat(min(max(1.0, $0), 4.0)) }), in: 1.0...4.0)
                Image(systemName: "plus.magnifyingglass")
            }
            .padding(.horizontal)

            HStack(spacing: 16) {
                Button("Cancelar") { onCancel() }
                    .buttonStyle(.bordered)
                Button("Guardar") {
                    if let img = renderCroppedImage() { onSave(img) }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    private func renderCroppedImage() -> UIImage? {
        // Render the visible square area at frameSize x frameSize to a UIImage
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: frameSize, height: frameSize))
        let image = renderer.image { ctx in
            UIColor.systemGray6.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: frameSize, height: frameSize))

            // Compute draw rect for original within the frame applying scale and offset
            let imgSize = original.size
            // Scale to cover
            let baseScale = max(frameSize / imgSize.width, frameSize / imgSize.height)
            let totalScale = baseScale * scale
            let drawSize = CGSize(width: imgSize.width * totalScale, height: imgSize.height * totalScale)
            let origin = CGPoint(x: (frameSize - drawSize.width) / 2.0 + offset.width,
                                 y: (frameSize - drawSize.height) / 2.0 + offset.height)
            original.draw(in: CGRect(origin: origin, size: drawSize))
        }
        return image
    }
}


