import SwiftUI

@main
struct RallyHubApp: App {
    init() {
        RallyAppearance.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
    }
}
