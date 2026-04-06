import SwiftUI

struct AvatarFullScreenView: View {
    let image: UIImage?
    let onClose: () -> Void
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(MagnificationGesture().onChanged { value in
                        scale = max(1.0, value)
                    })
                    .gesture(DragGesture().onChanged { value in
                        offset = value.translation
                    })
                    .animation(.spring(), value: scale)
                    .animation(.spring(), value: offset)
            }

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                    .padding(16)
            }
        }
    }
}


