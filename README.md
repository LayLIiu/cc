# Claude Code Mobile

移动端 Claude Code 助手，支持 iOS 和 Android。

## 功能

- 📱 查看会话列表
- 💬 继续对话
- 🔄 实时同步

## 开发

### 环境要求

- Node.js 18+
- Bun 或 npm
- Expo CLI

### 安装依赖

```bash
bun install
```

### 启动开发服务器

```bash
bun start
```

### 运行模拟器

```bash
# iOS
bun run ios

# Android
bun run android
```

## 项目结构

```
cc-haha-mobile/
├── app/           # 页面路由 (expo-router)
│   ├── (auth)/    # 登录相关页面
│   ├── (tabs)/    # 主页面标签栏
│   └── chat/      # 对话页面
├── components/    # 公共组件
├── stores/        # Zustand 状态管理
├── api/           # API 客户端
├── types/         # TypeScript 类型定义
└── assets/        # 静态资源
```

## 使用

1. 确保桌面端应用已启动并开启服务
2. 在移动端输入服务器地址（如 `http://192.168.1.100:3456`）
3. 连接成功后即可查看会话列表并继续对话
