import SwiftUI

struct RootView: View {
    @Bindable private var auth = AuthService.shared
    @State private var showSplash = true

    var body: some View {
        ZStack {
            Group {
                if !AppFirebaseConfig.isPlistConfigured {
                    FirebaseSetupView()
                } else if auth.isLoggedIn {
                    CircleListView()
                } else {
                    LoginView()
                }
            }

            if showSplash {
                SplashOverlayView(isPresented: $showSplash)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeOut(duration: 1.5), value: showSplash)
        .task {
            guard AppFirebaseConfig.isPlistConfigured else { return }
            auth.startAuthListener()
            await auth.bootstrapSession()
        }
    }
}
