import SwiftUI

@main
struct MuhomorGovorunIOSApp: App {
    @State private var config = AppConfig.load()
    @State private var ttsService = TTSService()

    var body: some Scene {
        WindowGroup {
            ContentView(config: $config)
                .environment(ttsService)
        }
    }
}
