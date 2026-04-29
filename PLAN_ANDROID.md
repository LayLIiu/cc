# Android 端实现计划 — Kotlin + Jetpack Compose

## 技术栈

| 类别 | 选择 |
|------|------|
| 语言 | Kotlin 2.0 |
| UI 框架 | Jetpack Compose + Material 3 |
| 架构 | MVVM + 单 Activity |
| 状态管理 | ViewModel + StateFlow + Compose State |
| 网络 | OkHttp + Retrofit + Gson |
| WebSocket | OkHttp WebSocket |
| 持久化 | DataStore (Preferences) + Room |
| 依赖注入 | 手动 DI（轻量级，项目规模不大） |
| 导航 | Compose Navigation |
| 动画 | Compose Animation + Material Motion |
| 图片/Canvas | Compose Canvas（像素吉祥物自绘） |

## UI 风格定位：Material + iOS 混合

- **布局规范**：遵循 Material 3 间距、触摸目标、边距
- **颜色体系**：复用 iOS 端的 Indigo/Violet 色板，支持 4 种主题（light/dark/system/glass）
- **玻璃效果**：Android 端用 `GraphicsLayer` + `BlurEffect`（API 31+）模拟 iOS 液态玻璃，低版本用半透明卡片 fallback
- **导航模式**：底部浮动胶囊 Tab 栏（iOS 风格）+ Material 3 TopAppBar
- **聊天气泡**：微信式左右对齐 + Material 卡片样式
- **动画**：Compose spring 动画模拟 iOS 弹簧效果
- **品牌特色**：保留像素吉祥物 PixelMascot、ContextRing 环形进度条

## 项目结构

```
ClaudeCodeAndroid/
├── app/
│   ├── build.gradle.kts
│   └── src/main/
│       ├── AndroidManifest.xml
│       ├── java/com/ccha/android/
│       │   ├── ClaudeCodeApp.kt              # Application
│       │   ├── MainActivity.kt               # 单 Activity
│       │   │
│       │   ├── data/
│       │   │   ├── model/
│       │   │   │   ├── Session.kt            # 会话模型
│       │   │   │   ├── Message.kt            # 消息模型（7种类型）
│       │   │   │   ├── Provider.kt           # 服务商模型
│       │   │   │   ├── User.kt              # 用户模型
│       │   │   │   └── WSMessage.kt         # WebSocket 消息
│       │   │   ├── store/
│       │   │   │   ├── AuthStore.kt          # 认证状态
│       │   │   │   ├── SessionStore.kt       # 会话+消息状态
│       │   │   │   ├── ProviderStore.kt      # 服务商状态
│       │   │   │   └── AppStore.kt           # 主题/全局设置
│       │   │   ├── api/
│       │   │   │   ├── ApiClient.kt          # Retrofit API
│       │   │   │   └── ApiRoutes.kt          # API 路由定义
│       │   │   └── websocket/
│       │   │       └── WebSocketManager.kt   # WebSocket 管理
│       │   │
│       │   ├── ui/
│       │   │   ├── theme/
│       │   │   │   ├── Theme.kt             # 主题系统（4模式）
│       │   │   │   ├── Color.kt             # 颜色定义
│       │   │   │   └── GlassEffect.kt       # 玻璃效果实现
│       │   │   │
│       │   │   ├── navigation/
│       │   │   │   └── AppNavigation.kt      # 导航图
│       │   │   │
│       │   │   ├── auth/
│       │   │   │   └── LoginScreen.kt        # 登录页
│       │   │   │
│       │   │   ├── sessions/
│       │   │   │   ├── SessionsScreen.kt     # 会话列表
│       │   │   │   └── NewSessionSheet.kt    # 新建会话底部弹窗
│       │   │   │
│       │   │   ├── chat/
│       │   │   │   ├── ChatScreen.kt         # 聊天页
│       │   │   │   ├── ChatInput.kt          # 输入栏
│       │   │   │   ├── MessageBubble.kt      # 消息气泡（7种类型）
│       │   │   │   ├── PermissionDialog.kt   # 权限对话框
│       │   │   │   └── QuestionDialog.kt     # 问题选项对话框
│       │   │   │
│       │   │   ├── providers/
│       │   │   │   ├── ProvidersScreen.kt    # 服务商管理
│       │   │   │   └── ProviderFormSheet.kt  # 添加/编辑服务商
│       │   │   │
│       │   │   ├── settings/
│       │   │   │   └── SettingsScreen.kt     # 设置页
│       │   │   │
│       │   │   ├── components/
│       │   │   │   ├── GlassTabBar.kt        # 浮动胶囊 Tab 栏
│       │   │   │   ├── PixelMascot.kt        # 像素吉祥物 Canvas
│       │   │   │   ├── ContextRing.kt        # 上下文环形进度
│       │   │   │   ├── ThinkingBlock.kt      # 思考折叠块
│       │   │   │   ├── ToolCallBlock.kt      # 工具调用折叠块
│       │   │   │   ├── MarkdownRenderer.kt   # Markdown 渲染器
│       │   │   │   ├── ModelSelector.kt      # 模型选择器
│       │   │   │   └── NetworkModeSlider.kt  # 网络模式切换
│       │   │   │
│       │   │   └── import/
│       │   │       └── ImportScreen.kt       # 导入对话页
│       │   │
│       │   └── util/
│       │       ├── NetworkUtils.kt           # 网络工具
│       │       └── Extensions.kt             # 通用扩展函数
│       │
│       └── res/
│           ├── values/
│           │   ├── strings.xml
│           │   ├── colors.xml
│           │   └── themes.xml
│           └── drawable/
│               └── ic_launcher.xml
│
├── build.gradle.kts          # 根构建
├── settings.gradle.kts
└── gradle.properties
```

## 实现阶段

### 阶段 1：项目骨架 + 主题系统
- 创建 Compose 项目结构
- 实现 4 种主题模式（light/dark/system/glass）
- 颜色体系（复用 iOS 端色板）
- 玻璃效果组件（BlurEffect + fallback）
- 单 Activity + Navigation 骨架

### 阶段 2：核心组件
- GlassTabBar：浮动胶囊 Tab 栏 + 弹簧滑动指示器
- PixelMascot：Canvas 像素风吉祥物 + 4 态动画
- ContextRing：Compose Canvas 环形进度条
- MarkdownRenderer：轻量 Markdown 解析 + 渲染
- ThinkingBlock / ToolCallBlock：折叠展开组件
- ModelSelector：模型选择弹窗
- NetworkModeSlider：局域网/公网切换滑块

### 阶段 3：页面实现
- LoginScreen：配对码 + 手动输入双模式
- SessionsScreen：会话列表 + 日期分组 + 搜索 + 下拉刷新 + 侧滑删除
- ChatScreen：倒序列表 + 消息气泡 + 流式输入 + 权限/问题对话框
- ProvidersScreen：服务商管理 + 配对码 + 隧道
- SettingsScreen：网络/外观/数据管理/关于
- ImportScreen：对话导入

### 阶段 4：数据层 + 后端对接
- ApiClient（Retrofit）
- WebSocketManager（OkHttp）
- AuthStore / SessionStore / ProviderStore（StateFlow）
- DataStore 持久化
- 消息去重 + 状态同步

## 页面设计要点

### 1. LoginScreen
- 顶部 Logo（像素风图标 + "Claude Code" 大标题）
- Tab 切换：配对码 | 手动输入（Material TabRow）
- 配对码模式：输入框 + 连接按钮
- 手动模式：服务器地址输入 + 连接按钮
- 4 步使用说明卡片
- 玻璃背景效果

### 2. SessionsScreen
- 顶部：标题 "Claude Code" + 搜索按钮 + 新建按钮（圆形）
- 搜索栏：展开式 Material SearchBar
- 会话分组：今天 / 昨天 / 最近7天 / 更早
- 会话卡片：PixelMascot 头像 + 标题 + 项目路径 + 状态徽章 + ContextRing
- 侧滑删除 + 确认对话框
- 下拉刷新（Material PullRefresh）
- 新建对话底部 Sheet

### 3. ChatScreen
- 自定义 TopBar：标题 + 状态点（闪烁动画）+ ContextRing
- 消息列表：LazyColumn 倒序
- 7 种消息气泡：
  - 用户消息：右对齐、primary 色背景、白字
  - AI 文本：左对齐、surface 色背景 + 细边框、MarkdownRenderer
  - 思考块：左对齐、折叠、脉冲动画
  - 工具调用：左对齐、折叠、工具图标 + 状态
  - 工具结果：折叠在工具调用内
  - 权限请求：全屏 Dialog、允许/拒绝按钮
  - 问题选项：全屏 Dialog、选项列表 + 自定义输入
- 底部输入栏：ModelSelector + 文本输入框 + 发送/停止按钮
- 玻璃效果输入栏
- "最新消息" 悬浮按钮

### 4. ProvidersScreen
- 连接设置卡片：配对码、局域网地址、公网隧道开关
- 官方认证卡片
- 自定义服务商卡片列表
- 添加/编辑服务商底部 Sheet

### 5. SettingsScreen
- 账户区：用户名
- 连接区：网络模式滑块（LAN/Tunnel）、地址编辑、连接速度测试
- 外观区：主题选择（4种）
- 数据管理区：导入对话
- 关于区：版本号
- 退出登录按钮

## 关键技术决策

1. **玻璃效果**：API 31+ 使用 `Modifier.graphicsLayer { renderEffect = BlurEffect }` + 半透明背景；低版本用 `CardDefaults.elevatedCardColors` 模拟
2. **Tab 栏动画**：`Animatable` + `spring` 实现指示器滑动，与 iOS 端 `matchedGeometryEffect` 效果一致
3. **消息列表倒序**：`LazyColumn` + `reverseLayout = true`，配合 `itemKey` 去重
4. **像素吉祥物**：`Canvas` 绘制 + `rememberInfiniteTransition` 动画循环
5. **Markdown 渲染**：自实现轻量解析器（与 iOS/RN 端对齐），`AnnotatedString` + `Builder` 渲染
6. **状态管理**：全局 Store 用 `object` 单例 + `MutableStateFlow`，ViewModel 内用 `StateFlow`
