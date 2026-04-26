// iOS 原生 Claude Code 客户端
// 使用 SwiftUI + 液态玻璃效果

import SwiftUI

@main
struct ClaudeCodeApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authStore = AuthStore()
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var providerStore = ProviderStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(authStore)
                .environmentObject(sessionStore)
                .environmentObject(providerStore)
                .preferredColorScheme(appState.colorScheme)
        }
    }
}
