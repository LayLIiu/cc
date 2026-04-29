/**
 * 聊天页面
 * 完全还原 iOS 端 ChatView UI
 */

import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { MarkdownRenderer } from '../components/MarkdownRenderer';
import { PixelMascot, MascotStatus, mapSessionStatusToMascot } from '../components/PixelMascot';

const DOMAIN = 0x0000;
const TAG = 'ChatPage';

// 消息类型
enum MessageType {
  User = 'user',
  Assistant = 'assistant',
  Thinking = 'thinking',
  ToolUse = 'tool_use',
  ToolResult = 'tool_result',
  PermissionRequest = 'permission_request',
  Question = 'question',
  TaskList = 'task_list'
}

// 会话状态
enum SessionStatus {
  Idle = 'idle',
  Thinking = 'thinking',
  Streaming = 'streaming',
  ToolExecuting = 'tool_executing',
  PermissionPending = 'permission_pending',
  QuestionPending = 'question_pending',
  Completed = 'completed'
}

// 消息数据接口
interface Message {
  id: string;
  type: MessageType;
  content: string;
  timestamp: string;
  isStreaming?: boolean;
  toolName?: string;
  toolInput?: ToolInput;
  toolStatus?: string;
  toolResult?: string;
  permissionId?: string;
  permissionDescription?: string;
  isPermissionHandled?: boolean;
  permissionResult?: boolean;
  questionId?: string;
  options?: string[];
  isQuestionAnswered?: boolean;
  selectedAnswer?: string;
  tasks?: TaskItem[];
}

// 任务项
interface TaskItem {
  id: string;
  content: string;
  status: string;
}

// 工具输入接口
interface ToolInput {
  command?: string;
  file?: string;
  content?: string;
}

// 丰富的测试消息数据
const testMessages: Message[] = [
  {
    id: '1',
    type: MessageType.User,
    content: '帮我创建一个 React + TypeScript 项目，并配置好 ESLint 和 Prettier',
    timestamp: '2026-04-28T10:00:00Z'
  } as Message,
  {
    id: '2',
    type: MessageType.Thinking,
    content: '用户想要创建一个新的 React 项目，需要：\n1. 使用 Vite 创建项目（更快的构建速度）\n2. 配置 TypeScript\n3. 安装和配置 ESLint\n4. 安装和配置 Prettier\n\n让我先检查当前目录，然后逐步完成这些任务...',
    timestamp: '2026-04-28T10:00:05Z'
  } as Message,
  {
    id: '3',
    type: MessageType.ToolUse,
    content: '',
    timestamp: '2026-04-28T10:00:10Z',
    toolName: 'Bash',
    toolInput: { command: 'npm create vite@latest my-react-app -- --template react-ts' } as ToolInput,
    toolStatus: 'completed',
    toolResult: '✓ 项目创建成功！'
  } as Message,
  {
    id: '4',
    type: MessageType.ToolUse,
    content: '',
    timestamp: '2026-04-28T10:00:20Z',
    toolName: 'Bash',
    toolInput: { command: 'cd my-react-app && npm install' } as ToolInput,
    toolStatus: 'completed',
    toolResult: 'added 142 packages in 12s'
  } as Message,
  {
    id: '5',
    type: MessageType.ToolUse,
    content: '',
    timestamp: '2026-04-28T10:00:30Z',
    toolName: 'Write',
    toolInput: { file: '.eslintrc.cjs', content: 'module.exports = {...}' } as ToolInput,
    toolStatus: 'completed',
    toolResult: '文件已创建'
  } as Message,
  {
    id: '6',
    type: MessageType.TaskList,
    content: '',
    timestamp: '2026-04-28T10:00:35Z',
    tasks: [
      { id: 't1', content: '创建 React + TS 项目', status: 'completed' } as TaskItem,
      { id: 't2', content: '安装项目依赖', status: 'completed' } as TaskItem,
      { id: 't3', content: '配置 ESLint', status: 'completed' } as TaskItem,
      { id: 't4', content: '配置 Prettier', status: 'in_progress' } as TaskItem,
      { id: 't5', content: '创建示例组件', status: 'pending' } as TaskItem
    ]
  } as Message,
  {
    id: '7',
    type: MessageType.Assistant,
    content: `## 项目创建成功！🎉

我已经为你创建了一个完整的 **React + TypeScript** 项目，配置包括：

### 已完成的配置

- ✅ React 18 + TypeScript 5.0
- ✅ Vite 构建工具（极速热更新）
- ✅ ESLint 代码检查
- ✅ Prettier 代码格式化

### 项目结构

\`\`\`
my-react-app/
├── src/
│   ├── App.tsx          # 主应用组件
│   ├── main.tsx         # 入口文件
│   └── vite-env.d.ts    # 类型声明
├── public/
├── .eslintrc.cjs        # ESLint 配置
├── .prettierrc          # Prettier 配置
├── tsconfig.json        # TypeScript 配置
└── vite.config.ts       # Vite 配置
\`\`\`

### 启动项目

运行以下命令启动开发服务器：

\`\`\`bash
cd my-react-app
npm run dev
\`\`\`

### 可用脚本

1. \`npm run dev\` - 启动开发服务器
2. \`npm run build\` - 构建生产版本
3. \`npm run lint\` - 运行代码检查
4. \`npm run format\` - 格式化代码

> 💡 **提示**: 项目已在 \`localhost:5173\` 上运行，支持热模块替换 (HMR)。

需要我帮你创建一些示例组件吗？`,
    timestamp: '2026-04-28T10:01:00Z'
  } as Message,
  {
    id: '8',
    type: MessageType.User,
    content: '好的，帮我创建一个 Button 组件，支持不同样式',
    timestamp: '2026-04-28T10:02:00Z'
  } as Message,
  {
    id: '9',
    type: MessageType.Thinking,
    content: '用户需要一个可复用的 Button 组件。我会创建：\n1. 支持 primary、secondary、outline 三种样式\n2. 支持 small、medium、large 三种尺寸\n3. 支持禁用状态和加载状态\n4. 完整的 TypeScript 类型定义',
    timestamp: '2026-04-28T10:02:05Z'
  } as Message,
  {
    id: '10',
    type: MessageType.PermissionRequest,
    content: '',
    timestamp: '2026-04-28T10:02:10Z',
    toolName: 'Write',
    toolInput: { file: 'src/components/Button.tsx' } as ToolInput,
    permissionId: 'perm-1',
    permissionDescription: '创建新文件 src/components/Button.tsx (约 150 行代码)',
    isPermissionHandled: true,
    permissionResult: true
  } as Message,
  {
    id: '11',
    type: MessageType.Assistant,
    content: `## Button 组件已创建！

我创建了一个功能完善的 Button 组件：

\`\`\`tsx
import React from 'react';

interface ButtonProps {
  variant?: 'primary' | 'secondary' | 'outline';
  size?: 'small' | 'medium' | 'large';
  loading?: boolean;
  disabled?: boolean;
  children: React.ReactNode;
  onClick?: () => void;
}

export const Button: React.FC<ButtonProps> = ({
  variant = 'primary',
  size = 'medium',
  loading = false,
  disabled = false,
  children,
  onClick
}) => {
  // 组件实现...
  return (
    <button className={\`btn btn-\${variant} btn-\${size}\`}>
      {loading ? <Spinner /> : children}
    </button>
  );
};
\`\`\`

### 使用示例

\`\`\`tsx
// 主要按钮
<Button variant="primary" onClick={handleClick}>
  确认
</Button>

// 次要按钮
<Button variant="secondary" size="large">
  取消
</Button>

// 加载状态
<Button loading>
  提交中...
</Button>
\`\`\`

组件支持以下属性：

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| variant | string | 'primary' | 按钮样式 |
| size | string | 'medium' | 按钮尺寸 |
| loading | boolean | false | 加载状态 |
| disabled | boolean | false | 禁用状态 |

需要我添加更多功能吗？比如图标支持？`,
    timestamp: '2026-04-28T10:02:30Z'
  },
  {
    id: '12',
    type: MessageType.Question,
    content: '你想让 Button 组件支持图标吗？',
    timestamp: '2026-04-28T10:02:35Z',
    questionId: 'q-1',
    options: ['添加左图标', '添加右图标', '两边都支持', '暂不需要'],
    isQuestionAnswered: true,
    selectedAnswer: '两边都支持'
  },
  {
    id: '13',
    type: MessageType.TaskList,
    content: '',
    timestamp: '2026-04-28T10:03:00Z',
    tasks: [
      { id: 't1', content: '创建 React + TS 项目', status: 'completed' },
      { id: 't2', content: '安装项目依赖', status: 'completed' },
      { id: 't3', content: '配置 ESLint', status: 'completed' },
      { id: 't4', content: '配置 Prettier', status: 'completed' },
      { id: 't5', content: '创建 Button 组件', status: 'completed' },
      { id: 't6', content: '添加图标支持', status: 'completed' }
    ]
  }
];

@Entry
@Component
struct ChatPage {
  @State private messages: Message[] = testMessages;
  @State private inputText: string = '';
  @State private streamingText: string = '';
  @State private streamingThinking: string = '';
  @State private chatStatus: SessionStatus = SessionStatus.Completed;
  @State private contextUsage: number = 45;
  @State private showScrollButton: boolean = false;
  @State private sessionTitle: string = 'React 项目开发';

  // 从路由获取的参数
  private sessionId: string = '';

  aboutToAppear() {
    // 获取路由参数
    try {
      const params = router.getParams() as Record<string, string>;
      if (params && params['sessionId']) {
        this.sessionId = params['sessionId'] as string;
      }
      if (params && params['title']) {
        this.sessionTitle = params['title'] as string;
      }
    } catch (e) {
      hilog.info(DOMAIN, TAG, 'No route params');
    }
  }

  // 计算已完成任务数量
  private getCompletedCount(tasks: TaskItem[] | undefined): number {
    if (!tasks) return 0;
    return tasks.filter(t => t.status === 'completed').length;
  }

  // 计算任务进度
  private getTaskProgress(tasks: TaskItem[] | undefined): number {
    if (!tasks || tasks.length === 0) return 0;
    const completed = tasks.filter(t => t.status === 'completed').length;
    return completed / tasks.length;
  }

  // 吉祥物状态
  private get mascotStatus(): MascotStatus {
    return mapSessionStatusToMascot(this.chatStatus);
  }

  build() {
    Column() {
      // 导航栏
      this.NavigationBar()

      // 消息列表
      Stack({ alignContent: Alignment.Bottom }) {
        this.MessageList()

        // 滚动到底部按钮
        if (this.showScrollButton) {
          this.ScrollToBottomButton()
        }
      }
      .layoutWeight(1)

      // 输入区域
      this.ChatInput()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F2F7')
  }

  // 导航栏
  @Builder
  NavigationBar() {
    Row() {
      // 返回按钮
      Button() {
        Text('‹')
          .fontSize(24)
          .fontColor('#6366F1')
      }
      .width(40)
      .height(40)
      .backgroundColor('transparent')
      .onClick(() => {
        router.back();
      })

      // 标题和状态
      Column() {
        Text(this.sessionTitle)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        // 状态行
        Row() {
          // 像素吉祥物
          PixelMascot({
            pixelSize: 16,
            status: this.mascotStatus,
            bodyColor: '#E86B4A'
          })
          .margin({ right: 4 })

          Text(this.statusText)
            .fontSize(12)
            .fontColor(this.statusColor)

          if (this.contextUsage > 0) {
            this.ContextRing()
          }
        }
        .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
      .margin({ left: -40 }) // 补偿返回按钮宽度

      // 占位
      Blank().width(40)
    }
    .width('100%')
    .height(88)
    .padding({ top: 44 })
    .backgroundColor('rgba(255, 255, 255, 0.95)')
    .backdropBlur(20)
  }

  // 上下文使用率环
  @Builder
  ContextRing() {
    Stack() {
      // 背景环
      Circle()
        .width(14)
        .height(14)
        .fill('transparent')
        .stroke('#E5E5EA')
        .strokeWidth(2)

      // 进度环
      Circle()
        .width(14)
        .height(14)
        .fill('transparent')
        .stroke(this.contextUsage > 80 ? '#FF9500' : '#6366F1')
        .strokeWidth(2)
    }
    .width(14)
    .height(14)
    .margin({ left: 6 })
  }

  private get statusText(): string {
    switch (this.chatStatus) {
      case SessionStatus.Idle: return '等待中';
      case SessionStatus.Thinking: return '思考中';
      case SessionStatus.Streaming: return '工作中';
      case SessionStatus.ToolExecuting: return '工具执行中';
      case SessionStatus.PermissionPending: return '等待权限';
      case SessionStatus.QuestionPending: return '等待回答';
      case SessionStatus.Completed: return '已完成';
      default: return '等待中';
    }
  }

  private get statusColor(): string {
    switch (this.chatStatus) {
      case SessionStatus.Idle: return '#6B6B6B';
      case SessionStatus.Completed: return '#34C759';
      case SessionStatus.PermissionPending: return '#FF9500';
      case SessionStatus.QuestionPending: return '#FFD60A';
      default: return '#34C759';
    }
  }

  // 消息列表
  @Builder
  MessageList() {
    List() {
      // 消息正序排列（最新在底部）
      ForEach(this.messages, (message: Message) => {
        ListItem() {
          this.MessageBubble(message)
        }
        .margin({ bottom: 12 })
      })

      // 流式思考
      if (this.streamingThinking.length > 0) {
        ListItem() {
          this.ThinkingBubble(this.streamingThinking, true)
        }
        .margin({ bottom: 12 })
      }

      // 流式文本
      if (this.streamingText.length > 0) {
        ListItem() {
          this.AssistantBubble(this.streamingText, true)
        }
        .margin({ bottom: 12 })
      }

      // 消息数量提示
      ListItem() {
        Text(`${this.messages.length} 条消息`)
          .fontSize(11)
          .fontColor('#6B6B6B')
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ bottom: 4, top: 8 })
      }
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  // 滚动到底部按钮
  @Builder
  ScrollToBottomButton() {
    Button() {
      Row() {
        Text('↓')
          .fontSize(10)
          .fontColor('#1A1A1A')
        Text('最新消息')
          .fontSize(11)
          .fontColor('#1A1A1A')
          .margin({ left: 4 })
      }
    }
    .height(28)
    .padding({ left: 12, right: 12 })
    .backgroundColor('rgba(255, 255, 255, 0.9)')
    .borderRadius(14)
    .margin({ bottom: 8 })
  }

  // 消息气泡分发
  @Builder
  MessageBubble(message: Message) {
    Row() {
      if (message.type === MessageType.User) {
        Blank()
      }

      // 根据类型显示不同气泡
      if (message.type === MessageType.User) {
        this.UserBubble(message.content)
      } else if (message.type === MessageType.Assistant) {
        this.AssistantBubble(message.content, message.isStreaming)
      } else if (message.type === MessageType.Thinking) {
        this.ThinkingBubble(message.content, message.isStreaming)
      } else if (message.type === MessageType.ToolUse) {
        this.ToolUseBubble(message)
      } else if (message.type === MessageType.ToolResult) {
        this.ToolResultBubble(message)
      } else if (message.type === MessageType.PermissionRequest) {
        this.PermissionRequestBubble(message)
      } else if (message.type === MessageType.Question) {
        this.QuestionBubble(message)
      } else if (message.type === MessageType.TaskList) {
        this.TaskListBubble(message)
      }

      if (message.type !== MessageType.User) {
        Blank()
      }
    }
    .width('100%')
  }

  // 用户消息气泡
  @Builder
  UserBubble(content: string) {
    Text(content)
      .fontSize(16)
      .fontColor('#1A1A1A')
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .constraintSize({ maxWidth: '75%' })
      .backgroundColor('rgba(255, 255, 255, 0.95)')
      .borderRadius(18)
  }

  // 助手消息气泡 - 使用 Markdown 渲染
  @Builder
  AssistantBubble(content: string, isStreaming?: boolean) {
    Column() {
      // Markdown 渲染
      MarkdownRenderer({ content: content })

      // 流式指示器
      if (isStreaming) {
        Row() {
          LoadingProgress()
            .width(12)
            .height(12)
            .color('#6366F1')
          Text(' 生成中...')
            .fontSize(12)
            .fontColor('#6366F1')
        }
        .margin({ top: 8 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .constraintSize({ maxWidth: '90%' })
    .backgroundColor('rgba(255, 255, 255, 0.95)')
    .borderRadius(18)
  }

  // 思考气泡
  @Builder
  ThinkingBubble(content: string, isStreaming?: boolean) {
    Column() {
      // 标题
      Row() {
        Text('💭')
          .fontSize(14)
        Text(' 思考过程')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#6B6B6B')

        if (isStreaming) {
          LoadingProgress()
            .width(12)
            .height(12)
            .color('#6B6B6B')
            .margin({ left: 8 })
        }
      }
      .width('100%')
      .margin({ bottom: 8 })

      // 思考内容
      Text(content)
        .fontSize(14)
        .fontColor('#6B6B6B')
        .fontStyle(FontStyle.Italic)
        .maxLines(30)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .constraintSize({ maxWidth: '85%' })
    .backgroundColor('rgba(99, 102, 241, 0.08)')
    .borderRadius(12)
    .border({ width: 1, color: 'rgba(99, 102, 241, 0.2)' })
  }

  // 工具调用气泡
  @Builder
  ToolUseBubble(message: Message) {
    Column() {
      // 工具名称
      Row() {
        // 工具图标
        Column() {
          Text('⚡')
            .fontSize(14)
        }
        .width(24)
        .height(24)
        .backgroundColor('rgba(99, 102, 241, 0.15)')
        .borderRadius(6)
        .justifyContent(FlexAlign.Center)

        Text(message.toolName || 'Unknown')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A1A')
          .margin({ left: 8 })

        Blank()

        // 状态图标
        if (message.toolStatus === 'completed') {
          Text('✓')
            .fontSize(14)
            .fontColor('#34C759')
        } else if (message.toolStatus === 'failed') {
          Text('✗')
            .fontSize(14)
            .fontColor('#FF3B30')
        } else if (message.toolStatus === 'running') {
          LoadingProgress()
            .width(14)
            .height(14)
            .color('#6366F1')
        }
      }
      .width('100%')

      // 工具输入
      if (message.toolInput && Object.keys(message.toolInput).length > 0) {
        Column() {
          ForEach(Object.keys(message.toolInput), (key: string) => {
            Row() {
              Text(key + ': ')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor('#6B6B6B')
              Text(String((message.toolInput as Record<string, Object>)[key] || '').substring(0, 60))
                .fontSize(12)
                .fontColor('#1A1A1A')
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .margin({ top: 4 })
            .alignItems(VerticalAlign.Top)
          })
        }
        .width('100%')
        .padding(8)
        .backgroundColor('rgba(0, 0, 0, 0.03)')
        .borderRadius(6)
        .margin({ top: 8 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .constraintSize({ maxWidth: '85%' })
    .backgroundColor('rgba(255, 255, 255, 0.95)')
    .borderRadius(12)
  }

  // 工具结果气泡
  @Builder
  ToolResultBubble(message: Message) {
    if (message.toolResult && !this.shouldHideToolResult(message.toolResult)) {
      Column() {
        Row() {
          Text('📄')
            .fontSize(12)
          Text(' 结果')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1A1A1A')

          Blank()

          if (message.toolStatus === 'completed') {
            Text('✓')
              .fontSize(12)
              .fontColor('#34C759')
          } else if (message.toolStatus === 'failed') {
            Text('✗')
              .fontSize(12)
              .fontColor('#FF3B30')
          }
        }
        .width('100%')
        .margin({ bottom: 8 })

        Text(message.toolResult)
          .fontSize(13)
          .fontColor('#1A1A1A')
          .maxLines(10)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .padding(12)
      .constraintSize({ maxWidth: '85%' })
      .backgroundColor('rgba(255, 255, 255, 0.95)')
      .borderRadius(12)
    }
  }

  // 检查是否应该隐藏工具结果
  private shouldHideToolResult(result: string): boolean {
    const trimmed = result.trim();
    return trimmed.startsWith('[{') && (
      trimmed.includes('"tool_use_id"') ||
      trimmed.includes('"tool_result"')
    );
  }

  // 权限请求气泡
  @Builder
  PermissionRequestBubble(message: Message) {
    Column() {
      // 标题
      Row() {
        Text('🔒')
          .fontSize(16)
        Text(' 权限请求')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
      }
      .width('100%')
      .margin({ bottom: 12 })

      // 工具名称
      Row() {
        Column() {
          Text('⚡')
            .fontSize(12)
        }
        .width(24)
        .height(24)
        .backgroundColor('rgba(99, 102, 241, 0.15)')
        .borderRadius(6)
        .justifyContent(FlexAlign.Center)

        Text(message.toolName || 'Unknown')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A1A')
          .margin({ left: 8 })
      }
      .width('100%')
      .margin({ bottom: 8 })

      // 描述
      if (message.permissionDescription) {
        Text(message.permissionDescription)
          .fontSize(14)
          .fontColor('#6B6B6B')
          .width('100%')
          .margin({ bottom: 12 })
      }

      // 已处理结果
      if (message.isPermissionHandled) {
        Row() {
          if (message.permissionResult) {
            Text('✓ 已允许')
              .fontSize(14)
              .fontColor('#34C759')
          } else {
            Text('✗ 已拒绝')
              .fontSize(14)
              .fontColor('#FF3B30')
          }
        }
      } else {
        // 按钮
        Row() {
          Button('拒绝')
            .fontSize(15)
            .fontColor('#1A1A1A')
            .backgroundColor('rgba(0, 0, 0, 0.08)')
            .borderRadius(8)
            .layoutWeight(1)
            .onClick(() => {
              // 处理拒绝
            })

          Button('允许')
            .fontSize(15)
            .fontColor(Color.White)
            .backgroundColor('#6366F1')
            .borderRadius(8)
            .layoutWeight(1)
            .margin({ left: 12 })
            .onClick(() => {
              // 处理允许
            })
        }
        .width('100%')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .constraintSize({ maxWidth: '90%' })
    .backgroundColor('rgba(255, 255, 255, 0.95)')
    .borderRadius(16)
  }

  // 问题选项气泡
  @Builder
  QuestionBubble(message: Message) {
    Column() {
      // 标题
      Row() {
        Text('❓')
          .fontSize(16)
        Text(' 请选择')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
      }
      .width('100%')
      .margin({ bottom: 12 })

      // 问题内容
      Text(message.content)
        .fontSize(14)
        .fontColor('#6B6B6B')
        .width('100%')
        .margin({ bottom: 12 })

      // 已回答结果
      if (message.isQuestionAnswered) {
        Row() {
          Text('✓ ')
            .fontSize(14)
            .fontColor('#34C759')
          Text(message.selectedAnswer || '')
            .fontSize(14)
            .fontColor('#34C759')
        }
      } else if (message.options && message.options.length > 0) {
        // 选项列表
        ForEach(message.options, (option: string) => {
          Button(option)
            .fontSize(14)
            .fontColor('#1A1A1A')
            .width('100%')
            .height(40)
            .backgroundColor('rgba(0, 0, 0, 0.05)')
            .borderRadius(8)
            .margin({ bottom: 8 })
            .onClick(() => {
              // 处理选择
            })
        })

        // 自定义输入按钮
        Button() {
          Row() {
            Text('✏️')
              .fontSize(12)
            Text(' 自定义输入')
              .fontSize(14)
              .fontColor('#6366F1')
          }
        }
        .width('100%')
        .height(40)
        .backgroundColor('rgba(99, 102, 241, 0.08)')
        .borderRadius(8)
        .onClick(() => {
          // 显示自定义输入
        })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .constraintSize({ maxWidth: '90%' })
    .backgroundColor('rgba(255, 255, 255, 0.95)')
    .borderRadius(16)
  }

  // 任务列表气泡
  @Builder
  TaskListBubble(message: Message) {
    Column() {
      // 标题
      Row() {
        Text('📋')
          .fontSize(16)
        Text(' 任务计划')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')

        Blank()

        if (message.tasks && message.tasks.length > 0) {
          Text(`${this.getCompletedCount(message.tasks)}/${message.tasks.length}`)
            .fontSize(12)
            .fontColor('#6B6B6B')
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor('rgba(0, 0, 0, 0.05)')
            .borderRadius(6)
        }
      }
      .width('100%')
      .margin({ bottom: 12 })

      // 任务列表
      if (message.tasks) {
        ForEach(message.tasks, (task: TaskItem) => {
          Row() {
            // 状态图标
            if (task.status === 'in_progress') {
              LoadingProgress()
                .width(20)
                .height(20)
                .color('#6366F1')
            } else if (task.status === 'completed') {
              Text('✓')
                .fontSize(14)
                .fontColor('#34C759')
            } else {
              Text('○')
                .fontSize(14)
                .fontColor('#C7C7CC')
            }

            // 任务内容
            Text(task.content)
              .fontSize(14)
              .fontColor(task.status === 'completed' ? '#6B6B6B' : '#1A1A1A')
              .margin({ left: 12 })
              .decoration({
                type: task.status === 'completed' ? TextDecorationType.LineThrough : TextDecorationType.None
              })

            Blank()
          }
          .width('100%')
          .height(32)
          .padding({ left: 8, right: 8 })
          .backgroundColor(task.status === 'in_progress' ? 'rgba(99, 102, 241, 0.08)' : 'transparent')
          .borderRadius(8)
        })

        // 进度条

        Column() {
          Stack({ alignContent: Alignment.Start }) {
            Row()
              .width('100%')
              .height(6)
              .backgroundColor('rgba(0, 0, 0, 0.1)')
              .borderRadius(3)

            Row()
              .width(`${this.getTaskProgress(message.tasks) * 100}%`)
              .height(6)
              .backgroundColor('#6366F1')
              .borderRadius(3)
          }
          .width('100%')
          .margin({ top: 12 })

          Text(`已完成 ${this.getCompletedCount(message.tasks)} / ${message.tasks ? message.tasks.length : 0} 项任务`)
            .fontSize(12)
            .fontColor('#6B6B6B')
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 4 })
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .constraintSize({ maxWidth: '90%' })
    .backgroundColor('rgba(255, 255, 255, 0.95)')
    .borderRadius(16)
  }

  // 输入区域
  @Builder
  ChatInput() {
    Row() {
      // 模型选择器
      Button() {
        Row() {
          Text('🤖')
            .fontSize(14)
          Text(' Sonnet')
            .fontSize(12)
            .fontColor('#6B6B6B')
        }
      }
      .height(36)
      .padding({ left: 8, right: 8 })
      .backgroundColor('rgba(0, 0, 0, 0.05)')
      .borderRadius(8)

      // 输入框
      TextArea({ placeholder: '发送消息...', text: this.inputText })
        .layoutWeight(1)
        .height(40)
        .fontSize(16)
        .backgroundColor('rgba(255, 255, 255, 0.85)')
        .borderRadius(20)
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .onChange((value: string) => {
          this.inputText = value;
        })

      // 发送/停止按钮
      Button() {
        if (this.chatStatus === SessionStatus.Idle) {
          Text('发送')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.inputText.length > 0 ? Color.White : '#C7C7CC')
        } else {
          Text('停止')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
        }
      }
      .height(36)
      .padding({ left: 12, right: 12 })
      .backgroundColor(
        this.inputText.length > 0 || this.chatStatus !== SessionStatus.Idle
          ? '#6366F1'
          : 'rgba(0, 0, 0, 0.1)'
      )
      .borderRadius(18)
      .enabled(this.inputText.length > 0 || this.chatStatus !== SessionStatus.Idle)
      .onClick(() => {
        this.sendMessage();
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .backgroundColor('rgba(255, 255, 255, 0.95)')
    .backdropBlur(20)
  }

  // 发送消息
  private sendMessage() {
    if (this.inputText.length === 0) return;

    const content = this.inputText;
    this.inputText = '';

    // 添加用户消息
    const userMessage: Message = {
      id: `user-${Date.now()}`,
      type: MessageType.User,
      content: content,
      timestamp: new Date().toISOString()
    };

    this.messages.push(userMessage);
    this.chatStatus = SessionStatus.Thinking;

    // 模拟响应
    setTimeout(() => {
      const assistantMessage: Message = {
        id: `assistant-${Date.now()}`,
        type: MessageType.Assistant,
        content: `收到您的消息：**${content}**\n\n这是一个测试回复，用于验证 Markdown 渲染效果。\n\n### 功能列表\n- ✅ Markdown 渲染\n- ✅ 代码高亮\n- ✅ 列表支持\n\n\`\`\`typescript\nconst greeting = "Hello, World!";\nconsole.log(greeting);\n\`\`\``,
        timestamp: new Date().toISOString()
      };
      this.messages.push(assistantMessage);
      this.chatStatus = SessionStatus.Completed;
    }, 1000);
  }
}
