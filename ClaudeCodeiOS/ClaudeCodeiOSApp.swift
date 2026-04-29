// iOS 原生 Claude Code 客户端
// 使用 SwiftUI + 液态玻璃效果

import ActivityKit
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
                .onAppear {
                    checkLiveActivityAuthorization()
                }
        }
    }

    private func checkLiveActivityAuthorization() {
        // 检查是否支持 Live Activities
        let authorizationInfo = ActivityAuthorizationInfo()
        print("[LiveActivity] 📱 Authorization check:")
        print("[LiveActivity]   - areActivitiesEnabled: \(authorizationInfo.areActivitiesEnabled)")
        print("[LiveActivity]   - frequentPushesEnabled: \(authorizationInfo.frequentPushesEnabled)")

        if !authorizationInfo.areActivitiesEnabled {
            print("[LiveActivity] ⚠️ Live Activities not enabled. Please enable in Settings.")
        }
    }
}
