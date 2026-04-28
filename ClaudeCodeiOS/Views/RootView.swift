// 根视图 - 控制导航流程

import SwiftUI

struct RootView: View {
    @EnvironmentObject var authStore: AuthStore
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if authStore.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authStore.isLoggedIn)
        .onReceive(NotificationCenter.default.publisher(for: .openSession)) { notification in
            // 监听通知点击，跳转到对应会话
            if let sessionId = notification.userInfo?["sessionId"] as? String {
                appState.pendingNavigateToSession = sessionId
            }
        }
    }
}

// MARK: - 主标签视图

struct MainTabView: View {
    @State private var selectedTab: String = "sessions"
    @State private var hideTabBar: Bool = false
    @State private var animateTabBar: Bool = false
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var sessionStore: SessionStore
    @EnvironmentObject var authStore: AuthStore

    var body: some View {
        ZStack(alignment: .bottom) {
            // 内容
            Group {
                switch selectedTab {
                case "sessions":
                    SessionsView(hideTabBar: $hideTabBar, animateTabBar: $animateTabBar)
                case "providers":
                    ProvidersView()
                case "settings":
                    SettingsView(hideTabBar: $hideTabBar, animateTabBar: $animateTabBar)
                default:
                    SessionsView(hideTabBar: $hideTabBar, animateTabBar: $animateTabBar)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 液态玻璃 Tab 栏
            if !hideTabBar {
                LiquidGlassTabBar(
                    tabs: [
                        TabItem(id: "sessions", label: "会话", icon: Image(systemName: "bubble.left.and.bubble.right")),
                        TabItem(id: "providers", label: "服务商", icon: Image(systemName: "server.rack")),
                        TabItem(id: "settings", label: "设置", icon: Image(systemName: "gearshape.fill"))
                    ],
                    selectedTab: $selectedTab
                )
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(.keyboard)
        .animation(animateTabBar ? .spring(response: 0.4, dampingFraction: 0.75) : .none, value: hideTabBar)
        .onChange(of: selectedTab) { _, _ in
            hideTabBar = false
            animateTabBar = false
        }
        .onChange(of: appState.pendingNavigateToSession) { _, newValue in
            // 当有待导航会话时，切换到会话标签
            if newValue != nil && selectedTab != "sessions" {
                selectedTab = "sessions"
            }
        }
        .task {
            // 请求通知权限
            _ = await NotificationService.shared.requestAuthorization()

            // 启动时加载会话列表并订阅所有会话消息
            await sessionStore.fetchSessions()
            let serverUrl = authStore.serverUrl
            if !serverUrl.isEmpty {
                sessionStore.subscribeToAllSessions(serverUrl: serverUrl)
            }
        }
        .onChange(of: sessionStore.sessions.count) { _, _ in
            // 会话列表变化时更新订阅
            let serverUrl = authStore.serverUrl
            if !serverUrl.isEmpty {
                sessionStore.updateGlobalSubscription(serverUrl: serverUrl)
            }
        }
        .onChange(of: authStore.serverUrl) { _, newUrl in
            // 服务器地址变化时重新订阅
            if !newUrl.isEmpty {
                sessionStore.subscribeToAllSessions(serverUrl: newUrl)
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
        .environmentObject(AuthStore())
        .environmentObject(SessionStore())
        .environmentObject(ProviderStore())
}
