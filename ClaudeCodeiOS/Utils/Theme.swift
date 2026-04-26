// 主题系统 - iOS 26 原生液态玻璃效果

import SwiftUI

// MARK: - 主题模式

enum ThemeMode: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    case glass = "glass"

    var label: String {
        switch self {
        case .light: return "浅色"
        case .dark: return "深色"
        case .system: return "跟随系统"
        case .glass: return "液态玻璃"
        }
    }

    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "circle.lefthalf.filled"
        case .glass: return "sparkles"
        }
    }
}

// MARK: - 颜色定义

struct AppColors {
    struct Light {
        static let background = Color(hex: "F2F2F7")  // 灰白色背景
        static let surface = Color(hex: "E5E5EA")  // 更灰的表面色
        static let surfaceHover = Color(hex: "D8D8DD")
        static let text = Color(hex: "1A1A1A")
        static let textSecondary = Color(hex: "6B6B6B")
        static let textTertiary = Color(hex: "9A9A9A")
        static let border = Color(hex: "D1D1D6")
        static let primary = Color(hex: "6366F1")
        static let accent = Color(hex: "8B5CF6")
        static let error = Color(hex: "DC2626")
        static let success = Color(hex: "16A34A")
    }

    struct Dark {
        static let background = Color(hex: "0D0D0D")
        static let surface = Color(hex: "1A1A1A")
        static let surfaceHover = Color(hex: "262626")
        static let text = Color(hex: "F5F5F5")
        static let textSecondary = Color(hex: "A0A0A0")
        static let textTertiary = Color(hex: "666666")
        static let border = Color(hex: "2A2A2A")
        static let primary = Color(hex: "818CF8")
        static let accent = Color(hex: "A78BFA")
        static let error = Color(hex: "F87171")
        static let success = Color(hex: "4ADE80")
    }
}

// MARK: - 动态颜色扩展

extension Color {
    static var adaptiveBackground: Color {
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(AppColors.Dark.background)
                : UIColor(AppColors.Light.background)
        })
    }

    static var adaptiveSurface: Color {
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(AppColors.Dark.surface)
                : UIColor(AppColors.Light.surface)
        })
    }

    static var adaptiveText: Color {
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(AppColors.Dark.text)
                : UIColor(AppColors.Light.text)
        })
    }

    static var adaptiveTextSecondary: Color {
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(AppColors.Dark.textSecondary)
                : UIColor(AppColors.Light.textSecondary)
        })
    }

    static var adaptivePrimary: Color {
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(AppColors.Dark.primary)
                : UIColor(AppColors.Light.primary)
        })
    }
}

// MARK: - Color Hex 扩展

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - 玻璃卡片修饰器

/// iOS 26 原生液态玻璃效果
@available(iOS 26.0, *)
struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat

    init(cornerRadius: CGFloat = 16) {
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        content
            .glassEffect(.regular)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

/// 后备视图修饰器 - iOS 26 以下使用
struct FallbackGlassModifier: ViewModifier {
    var cornerRadius: CGFloat
    var isDark: Bool

    init(cornerRadius: CGFloat = 16, isDark: Bool = false) {
        self.cornerRadius = cornerRadius
        self.isDark = isDark
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isDark
                        ? Color(hex: "2C2C2E")
                        : Color(hex: "D1D1D6")
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        isDark
                            ? Color.white.opacity(0.15)
                            : Color.gray.opacity(0.25),
                        lineWidth: 0.5
                    )
            )
    }
}

// MARK: - 视图扩展

extension View {
    /// 应用玻璃效果卡片样式（用于小的 UI 元素）
    @ViewBuilder
    func liquidGlass(cornerRadius: CGFloat = 16, interactive: Bool = false, isDark: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            modifier(LiquidGlassModifier(cornerRadius: cornerRadius))
        } else {
            modifier(FallbackGlassModifier(cornerRadius: cornerRadius, isDark: isDark))
        }
    }

    /// 液态玻璃卡片
    func liquidGlassCard(padding: CGFloat = 16, isDark: Bool = false) -> some View {
        self
            .padding(padding)
            .liquidGlass(cornerRadius: 12, isDark: isDark)
    }

    /// 液态玻璃背景 - 用于全屏背景
    @ViewBuilder
    func liquidGlassBackground(isDark: Bool = false) -> some View {
        self.background(
            isDark
                ? Color(hex: "0D0D0D")
                : Color(hex: "E5E5EA")
        )
    }
}

// MARK: - 液态玻璃 Tab 栏 - 胶囊滑块样式

struct LiquidGlassTabBar: View {
    let tabs: [TabItem]
    @Binding var selectedTab: String
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    @Namespace private var animation

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tabs) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab.id
                    }
                } label: {
                    VStack(spacing: 4) {
                        tab.icon
                            .font(.system(size: 20))
                        Text(tab.label)
                            .font(.caption2)
                    }
                    .foregroundColor(selectedTab == tab.id
                        ? .white
                        : .adaptiveTextSecondary
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())  // 扩大点击区域到整个 tab 格子
                    .background {
                        if selectedTab == tab.id {
                            Capsule()
                                .fill(Color.adaptivePrimary)
                                .matchedGeometryEffect(id: "tab", in: animation)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .contentShape(Rectangle())  // 整行拦截点击，防止穿透到下面内容
        .liquidGlass(
            cornerRadius: 28,
            interactive: true,
            isDark: appState.themeMode == .dark || appState.themeMode == .glass
        )
        .padding(.horizontal, 16)
    }
}

struct TabItem: Identifiable {
    let id: String
    let label: String
    let icon: Image
}
