# Claude Code iOS 应用需求文档

> 本文档详细描述 Claude Code iOS 客户端的所有功能、UI 设计和技术实现要求，用于在其他平台（如鸿蒙 OS、Android 等）进行还原开发。

---

## 一、应用概述

### 1.1 基本信息
- **应用名称**: Claude Code
- **版本号**: 1.0.1
- **支持平台**: iOS 17.0+
- **应用类型**: AI 编程助手客户端

### 1.2 核心功能
- 连接 Claude Code 桌面端服务
- 实时聊天对话
- 会话管理
- 多服务商支持
- 通知推送

---

## 二、应用架构

### 2.1 目录结构
```
ClaudeCodeiOS/
├── ClaudeCodeiOSApp.swift    # 应用入口
├── Models/                   # 数据模型
│   └── Models.swift
├── Views/                    # 视图层
│   ├── RootView.swift        # 根视图
│   ├── Auth/                 # 登录相关
│   ├── Sessions/             # 会话列表
│   ├── Chat/                 # 聊天界面
│   ├── Providers/            # 服务商管理
│   ├── Settings/             # 设置页面
│   ├── Components/           # 公共组件
│   └── Shared/               # 共享视图
├── Stores/                   # 状态管理
│   ├── AppState.swift
│   ├── AuthStore.swift
│   ├── SessionStore.swift
│   └── ProviderStore.swift
├── Services/                 # 服务层
│   ├── APIService.swift
│   ├── WebSocketService.swift
│   └── NotificationService.swift
├── Utils/                    # 工具类
│   └── Theme.swift
└── Resources/                # 资源文件
    └── Assets.xcassets/
```

### 2.2 技术栈
- **UI 框架**: SwiftUI
- **网络请求**: URLSession + async/await
- **实时通信**: WebSocket (Starscream)
- **数据持久化**: UserDefaults + 本地 JSON 文件
- **状态管理**: ObservableObject + @Published

---

## 三、页面设计

### 3.1 登录页面 (LoginView)

#### UI 布局
```
┌─────────────────────────────────────┐
│                                     │
│           [应用 Logo]               │
│                                     │
│     Claude Code                     │
│     AI 编程助手                     │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 🔗 局域网                    │   │
│  │    自动发现的本地服务器      │   │
│  │    > 192.168.1.100:8080     │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 🌐 公网                      │   │
│  │    输入服务器地址            │   │
│  │    [___________________]     │   │
│  │    [测试延迟]  45ms          │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 📱 配对码                    │   │
│  │    扫描桌面端二维码          │   │
│  │    [输入配对码]              │   │
│  └─────────────────────────────┘   │
│                                     │
│        [连接] 按钮                  │
│                                     │
└─────────────────────────────────────┘
```

#### 功能需求
1. **局域网发现**
   - 自动扫描本地网络中的 Claude Code 服务
   - 显示服务器地址和延迟
   - 点击选择即可连接

2. **公网连接**
   - 手动输入服务器地址（支持 IP 或域名）
   - 测试延迟功能
   - 支持隧道服务

3. **配对码登录**
   - 输入桌面端显示的配对码（格式：host:port:token）
   - 自动解析并连接

4. **连接状态**
   - 连接中显示加载动画
   - 连接失败显示错误提示
   - 连接成功自动跳转主页面

---

### 3.2 主页面 (RootView)

#### UI 布局 - Tab 栏
```
┌─────────────────────────────────────┐
│                                     │
│         [当前页面内容]              │
│                                     │
│                                     │
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│   📋 会话   │   ⚙️ 设置   │   🤖 服务商  │
└─────────────────────────────────────┘
```

#### Tab 栏样式
- **选中状态**: 胶囊形状，主题色背景，白色文字
- **未选中状态**: 灰色文字，无背景
- **背景**: 液态玻璃效果 / 磨砂玻璃（浅色主题）
- **圆角**: 28px

---

### 3.3 会话列表页面 (SessionsView)

#### UI 布局
```
┌─────────────────────────────────────┐
│           📋 会话                   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 🔍 搜索会话...               │   │
│  └─────────────────────────────┘   │
│                                     │
│  今天                               │
│  ┌─────────────────────────────┐   │
│  │ 📁 我的项目                 │   │
│  │    /Users/xxx/project       │   │
│  │    💬 12 条消息  刚刚        │   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │ 📁 另一个项目               │   │
│  │    /Users/xxx/another       │   │
│  │    💬 5 条消息  2小时前     │   │
│  └─────────────────────────────┘   │
│                                     │
│  昨天                               │
│  ┌─────────────────────────────┐   │
│  │ 📁 旧项目                   │   │
│  │    /Users/xxx/old           │   │
│  │    💬 30 条消息  昨天       │   │
│  └─────────────────────────────┘   │
│                                     │
│           [+ 新建会话]              │
└─────────────────────────────────────┘
```

#### 功能需求
1. **会话分组**
   - 按时间分组：今天、昨天、最近7天、更早
   - 活跃会话自动移到"今天"

2. **会话卡片**
   - 显示项目名称/标题
   - 显示工作目录路径
   - 显示消息数量
   - 显示最后活动时间
   - 左滑删除

3. **搜索功能**
   - 按标题搜索
   - 按路径搜索

4. **新建会话**
   - 点击 + 按钮
   - 可选输入自定义路径
   - 自动创建并跳转聊天页面

---

### 3.4 聊天页面 (ChatView)

#### UI 布局
```
┌─────────────────────────────────────┐
│ ←  我的项目                    🔔   │
│         等待中  🟢                  │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 用户消息气泡                 │   │
│  │ 右对齐，蓝色背景             │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 🤔 思考中...                 │   │
│  │ 这里的思考内容会实时显示     │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 🔧 工具调用: Read            │   │
│  │    file_path: xxx.swift     │   │
│  │    ✓ 已完成                  │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 助手回复内容                 │   │
│  │ 支持 Markdown 渲染          │   │
│  │ - 代码高亮                   │   │
│  │ - 列表、表格等               │   │
│  └─────────────────────────────┘   │
│                                     │
│         [↓ 最新消息]                │
│                                     │
├─────────────────────────────────────┤
│  🤖  [输入消息...        ]   ➤      │
└─────────────────────────────────────┘
```

#### 消息类型

1. **用户消息 (userText)**
   - 右对齐
   - 背景：玻璃效果
   - 长按显示复制按钮

2. **助手消息 (assistantText)**
   - 左对齐
   - 支持 Markdown 渲染
   - 代码块语法高亮
   - 长按显示复制按钮

3. **思考内容 (thinking)**
   - 左对齐
   - 显示 🤔 图标
   - 流式显示时带动画

4. **工具调用 (toolUse)**
   - 显示工具名称
   - 显示输入参数
   - 显示执行状态（进行中/已完成/失败）

5. **工具结果 (toolResult)**
   - 显示结果内容
   - 状态指示器

6. **权限请求 (permissionRequest)**
   - 显示权限描述
   - 允许/拒绝按钮

7. **问题选项 (question)**
   - 显示问题和选项
   - 单选/多选
   - 提交按钮

8. **任务列表 (taskList)**
   - 显示任务进度
   - 进度条动画

#### 状态指示器
- **位置**: 导航栏标题下方
- **文字居中**: 状态文字固定在中央
- **小圆点**: 在文字左边，工作状态时呼吸闪烁
- **上下文使用率**: 在文字右边，环形进度显示

#### 状态类型
| 状态 | 文字 | 颜色 |
|------|------|------|
| idle | 等待中 | 灰色 |
| thinking | 思考中 | 橙色 |
| streaming | 工作中 | 绿色 |
| toolExecuting | 工具执行中 | 蓝色 |
| permissionPending | 等待权限 | 橙色 |
| questionPending | 等待回答 | 黄色 |
| completed | 已完成 | 绿色 |

#### 功能需求

1. **消息发送**
   - 输入框自适应高度
   - 发送按钮：空闲时显示发送图标，工作中显示停止图标
   - 发送后自动滚动到底部

2. **消息接收**
   - WebSocket 实时接收
   - 流式显示文字内容
   - 用户查看历史时不打断

3. **滚动行为**
   - 新消息到达时，只有在底部才自动滚动
   - 用户向上滚动查看历史时，显示"最新消息"按钮
   - 点击按钮回到最新位置

4. **复制功能**
   - 长按消息显示复制按钮
   - 点击复制后显示绿色"已复制"提示
   - 1.5秒后自动消失

---

### 3.5 服务商页面 (ProvidersView)

#### UI 布局
```
┌─────────────────────────────────────┐
│           服务商                    │
│                                     │
│  预设服务商                          │
│  ┌─────────────────────────────┐   │
│  │ OpenAI              [当前]  │   │
│  │ GPT-4o                      │   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │ Anthropic                   │   │
│  │ Claude 3.5 Sonnet           │   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │ Google Gemini               │   │
│  │ Gemini Pro                  │   │
│  └─────────────────────────────┘   │
│                                     │
│  自定义服务商                        │
│  ┌─────────────────────────────┐   │
│  │ 我的自定义                  │   │
│  │ API Key: sk-xxx...          │   │
│  │ Base URL: https://...       │   │
│  │              [测试] [删除]  │   │
│  └─────────────────────────────┘   │
│                                     │
│           [+ 添加服务商]            │
└─────────────────────────────────────┘
```

#### 功能需求
1. **预设服务商**
   - 显示常用服务商配置
   - 点击激活使用
   - 显示当前使用的服务商

2. **自定义服务商**
   - 添加自定义 API 配置
   - 输入名称、API Key、Base URL
   - 测试连接功能
   - 删除功能

---

### 3.6 设置页面 (SettingsView)

#### UI 布局
```
┌─────────────────────────────────────┐
│           设置                      │
│                                     │
│  连接设置                            │
│  ┌─────────────────────────────┐   │
│  │ 局域网地址                   │   │
│  │ 192.168.1.100:8080         │   │
│  │ 延迟: 45ms                  │   │
│  │              [测试] [编辑]  │   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │ 公网地址                     │   │
│  │ https://xxx.tunnel.com     │   │
│  │              [测试] [编辑]  │   │
│  └─────────────────────────────┘   │
│                                     │
│  外观设置                            │
│  ┌─────────────────────────────┐   │
│  │ 主题                         │   │
│  │ 浅色  ▶                     │   │
│  └─────────────────────────────┘   │
│                                     │
│  数据管理                            │
│  ┌─────────────────────────────┐   │
│  │ 导入对话                     │   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │ 存储信息                     │   │
│  │ 已使用 12.5 MB              │   │
│  └─────────────────────────────┘   │
│                                     │
│  关于                                │
│  ┌─────────────────────────────┐   │
│  │ 版本                         │   │
│  │ 1.0.1 (2026-04-26)          │   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │ 更新日志                     │   │
│  └─────────────────────────────┘   │
│                                     │
│        [退出登录]                    │
└─────────────────────────────────────┘
```

#### 主题选项
| 主题 | 描述 |
|------|------|
| 浅色 | 白色背景，磨砂玻璃效果 |
| 深色 | 深色背景，玻璃效果 |
| 跟随系统 | 根据系统设置自动切换 |
| 液态玻璃 | iOS 26 原生液态玻璃效果 |

---

## 四、组件设计

### 4.1 MarkdownRenderer (Markdown 渲染器)

**功能**:
- 渲染 Markdown 文本
- 代码块语法高亮
- 支持链接点击
- 支持列表、表格、引用等

**样式**:
- 代码块：深色背景，圆角 8px
- 行内代码：灰色背景
- 链接：主题色，下划线

### 4.2 ToolCallBlock (工具调用组件)

**功能**:
- 显示工具名称和参数
- 显示执行状态
- 可展开/收起详细信息

**状态**:
- pending: 显示加载动画
- running: 显示进度
- completed: 显示绿色勾
- failed: 显示红色叉

### 4.3 ThinkingBlock (思考组件)

**功能**:
- 显示 AI 思考过程
- 流式显示时带动画
- 可展开/收起

**样式**:
- 背景：玻璃效果
- 图标：🤔
- 文字：斜体，灰色

### 4.4 StatusIndicator (状态指示器)

**功能**:
- 显示当前工作状态
- 呼吸动画效果

**样式**:
- 圆点大小：10px
- 动画：缩放 0.8-1.2，透明度 0.5-1.0
- 周期：0.8 秒

### 4.5 ContextRingView (上下文使用率)

**功能**:
- 显示上下文使用百分比
- 环形进度条

**样式**:
- 大小：14px
- 线宽：2px
- 颜色：根据百分比变化（绿→黄→红）

---

## 五、数据模型

### 5.1 Session (会话)
```swift
struct Session: Identifiable, Codable {
    let id: String
    let title: String
    let projectPath: String?
    let workDir: String?
    let workDirExists: Bool?
    let createdAt: String
    let modifiedAt: String
    let messageCount: Int?
}
```

### 5.2 Message (消息)
```swift
struct Message: Identifiable, Codable {
    let id: String
    let type: MessageType
    let content: String
    let timestamp: String
    var toolName: String?
    var toolInput: [String: Any]?
    var toolResult: String?
    var toolStatus: ToolStatus?
    var isStreaming: Bool?
    // 权限请求相关
    var permissionId: String?
    var permissionDescription: String?
    var isPermissionHandled: Bool
    var permissionResult: Bool?
    // 问题选项相关
    var questionId: String?
    var options: [String]?
    var selectedAnswer: String?
    var isQuestionAnswered: Bool
    // 任务列表相关
    var tasks: [TaskItem]?
}

enum MessageType: String, Codable {
    case userText = "user_text"
    case assistantText = "assistant_text"
    case thinking
    case toolUse = "tool_use"
    case toolResult = "tool_result"
    case permissionRequest = "permission_request"
    case question
    case taskList = "task_list"
}

enum ToolStatus: String, Codable {
    case pending
    case running
    case completed
    case failed
}
```

### 5.3 Provider (服务商)
```swift
struct Provider: Identifiable, Codable {
    let id: String
    let name: String
    let apiFormat: APIFormat
    var apiKey: String?
    var baseUrl: String?
    var isActive: Bool
}

enum APIFormat: String, Codable {
    case openai
    case anthropic
    case gemini
    case custom
}
```

---

## 六、API 接口

### 6.1 基础 URL
- 局域网: `http://192.168.x.x:port`
- 公网: `https://xxx.tunnel.com`

### 6.2 接口列表

#### 获取会话列表
```
GET /api/sessions
Response: { sessions: [Session] }
```

#### 创建会话
```
POST /api/sessions
Body: { workDir: String? }
Response: { sessionId: String }
```

#### 删除会话
```
DELETE /api/sessions/{sessionId}
```

#### 获取消息列表
```
GET /api/sessions/{sessionId}/messages
Response: { messages: [Message] }
```

#### 获取服务商列表
```
GET /api/providers
Response: { providers: [Provider] }
```

#### 设置当前服务商
```
POST /api/providers/{providerId}/activate
```

#### 测试服务商
```
POST /api/providers/{providerId}/test
Response: { success: Bool, latency: Int }
```

### 6.3 WebSocket 接口

#### 连接地址
```
ws://host:port/ws?sessionId=xxx
```

#### 消息类型
```json
// 发送消息
{
  "type": "send_message",
  "content": "用户输入的内容"
}

// 接收消息类型
{
  "type": "content_start",
  "block_type": "text|thinking"
}

{
  "type": "content_delta",
  "text": "增量文本"
}

{
  "type": "content_complete"
}

{
  "type": "tool_use",
  "tool_name": "Read",
  "tool_input": { ... }
}

{
  "type": "tool_result",
  "tool_use_id": "xxx",
  "content": "结果内容"
}

{
  "type": "status",
  "state": "thinking|streaming|idle"
}

{
  "type": "token_usage",
  "percentage": 0.5
}

{
  "type": "permission_request",
  "permission_id": "xxx",
  "description": "权限描述"
}

{
  "type": "question",
  "question_id": "xxx",
  "options": ["A", "B", "C"]
}

{
  "type": "user_message_echo",
  "content": { ... }
}
```

---

## 七、主题系统

### 7.1 颜色定义

#### 浅色主题
```swift
background = "#F2F2F7"  // 灰白色背景
surface = "#E5E5EA"     // 更灰的表面色
text = "#1A1A1A"        // 主文字
textSecondary = "#6B6B6B" // 次要文字
primary = "#6366F1"     // 主题色
```

#### 深色主题
```swift
background = "#0D0D0D"  // 纯黑背景
surface = "#1A1A1A"     // 深灰表面
text = "#F5F5F5"        // 白色文字
textSecondary = "#A0A0A0" // 灰色文字
primary = "#818CF8"     // 亮紫色主题
```

### 7.2 玻璃效果

#### 浅色主题（磨砂玻璃）
- 背景：白色 90% 透明度
- 效果：高斯模糊
- 边框：灰色 20% 透明度

#### 深色主题（玻璃效果）
- 背景：深灰 #2C2C2E
- 边框：白色 15% 透明度

#### 液态玻璃效果（iOS 26+）
- 使用系统原生 `.glassEffect()` API

### 7.3 卡片样式
- 圆角：12-18px
- 内边距：12-16px
- 阴影：无或轻微阴影

---

## 八、动画效果

### 8.1 页面转场
- 导航推入：从右向左滑入
- 导航返回：从左向右滑出
- 模态弹出：从底部弹出

### 8.2 列表动画
- 新消息：从底部淡入
- 删除：向左滑出消失
- 刷新：下拉刷新动画

### 8.3 状态动画
- 加载中：旋转动画
- 思考中：三点跳动
- 工作中：呼吸闪烁

### 8.4 按钮动画
- 点击：缩放 0.95
- 长按：缓慢放大

---

## 九、通知系统

### 9.1 本地通知
- 新消息到达时发送通知
- 显示会话标题和消息摘要
- 点击通知跳转到对应会话

### 9.2 通知权限
- 首次进入聊天页面请求权限
- 用户可拒绝，不影响核心功能

---

## 十、数据持久化

### 10.1 UserDefaults
- 服务器地址
- 主题设置
- 当前激活的服务商 ID

### 10.2 本地文件
- 会话列表：`sessions.json`
- 消息缓存：`messages/{sessionId}.json`
- 服务商配置：`providers.json`

---

## 十一、错误处理

### 11.1 网络错误
- 显示错误提示
- 提供重试按钮
- 自动重连 WebSocket

### 11.2 数据错误
- JSON 解析失败时静默跳过
- 显示默认值

### 11.3 用户操作错误
- 输入验证
- 友好的错误提示

---

## 十二、性能优化

### 12.1 消息列表
- 使用 LazyVStack 懒加载
- 虚拟化长列表
- 分页加载历史消息

### 12.2 图片资源
- 使用 Asset Catalog
- 按需加载 @2x/@3x 图片

### 12.3 WebSocket
- 心跳保活
- 断线重连
- 消息队列

---

## 十三、安全考虑

### 13.1 数据安全
- API Key 不明文存储
- 敏感数据加密存储

### 13.2 网络安全
- HTTPS 传输
- WebSocket WSS

### 13.3 输入验证
- URL 格式验证
- 配对码格式验证

---

## 十四、鸿蒙 OS 迁移要点

### 14.1 UI 框架映射
| iOS (SwiftUI) | 鸿蒙 (ArkUI) |
|---------------|--------------|
| View | @Component struct |
| @State | @State |
| @Published | @Observed |
| ObservableObject | Observed |
| @EnvironmentObject | @Provide/@Consume |
| NavigationStack | NavDestination |
| ScrollView | Scroll |
| LazyVStack | List |
| HStack | Row |
| VStack | Column |
| ZStack | Stack |

### 14.2 关键差异
1. **液态玻璃效果**: 鸿蒙可能需要自定义实现毛玻璃效果
2. **动画系统**: 使用 animateTo 替代 SwiftUI 动画
3. **状态管理**: 使用 AppStorage 替代 UserDefaults
4. **网络请求**: 使用 @ohos/axios 或原生 http 模块
5. **WebSocket**: 使用 @ohos/websocket

### 14.3 需要特别处理的功能
1. 通知系统（鸿蒙推送服务）
2. 本地存储（鸿蒙 Preferences）
3. 主题切换（鸿蒙系统主题监听）

---

## 十五、测试要点

### 15.1 功能测试
- [ ] 登录流程（局域网/公网/配对码）
- [ ] 会话创建、删除、搜索
- [ ] 消息发送、接收、复制
- [ ] 工具调用显示
- [ ] 权限请求处理
- [ ] 服务商管理
- [ ] 主题切换
- [ ] 通知推送

### 15.2 边界测试
- [ ] 网络断开重连
- [ ] 长消息处理
- [ ] 大量会话列表
- [ ] 重复消息去重

### 15.3 兼容性测试
- [ ] 不同 iOS 版本
- [ ] 不同屏幕尺寸
- [ ] 深色/浅色模式

---

## 十六、版本历史

### v1.0.1 (2026-04-28)
- 修复消息重复显示问题
- 修复滚动被打断问题
- 添加浅色主题磨砂玻璃效果
- 隐藏 JSON 格式工具调用

### v1.0.0 (2026-04-26)
- 初始版本发布
- 支持局域网/公网/配对码登录
- 实现实时聊天功能
- 支持多服务商管理

---

*文档最后更新: 2026-04-28*
