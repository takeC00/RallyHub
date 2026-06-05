import SwiftUI

/// 起動直後にスプラッシュ画像を表示（Launch Screen の補完・RallyMatch と同様のフェード）
struct SplashOverlayView: View {
    @Binding var isPresented: Bool

    var body: some View {
        Image("LaunchSplash")
            .resizable()
            .scaledToFill()
            .frame(
                width: UIScreen.main.bounds.width,
                height: UIScreen.main.bounds.height
            )
            .clipped()
            .ignoresSafeArea()
            .onAppear {
                Task {
                    try? await Task.sleep(for: .seconds(2.0))
                    withAnimation(.easeOut(duration: 1.5)) {
                        isPresented = false
                    }
                }
            }
    }
}
