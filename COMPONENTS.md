# 移动端组件说明

本文档描述了为移动端添加的新组件功能。

## 已实现功能

### 1. Markdown 渲染

**文件**: `components/markdown/MarkdownRenderer.tsx`

**功能**:
- 支持完整的 Markdown 语法
- 代码块语法高亮（使用 react-syntax-highlighter）
- 标题（H1-H6）
- 列表（无序和有序）
- 链接（可点击打开）
- 粗体、斜体
- 行内代码
- 引用块
- 代码块支持复制功能

**使用示例**:
```tsx
import { MarkdownRenderer } from '@/components'

<MarkdownRenderer content="# Hello\n\n这是**粗体**文本。" />
```

### 2. 工具调用可视化

**文件**: `components/chat/ToolCallBlock.tsx`

**功能**:
- 展示工具调用的完整信息
- 显示工具名称、输入参数、执行结果
- 支持展开/折叠查看详情
- 显示执行状态（等待中、执行中、已完成、失败）
- 显示执行时间
- 支持分组展示多个工具调用

**使用示例**:
```tsx
import { ToolCallBlock, ToolCallGroup } from '@/components'

<ToolCallGroup title="文件操作">
  <ToolCallBlock
    toolName="Read"
    input={{ file_path: "/path/to/file.ts" }}
    status="completed"
    result="文件内容..."
    duration={234}
  />
</ToolCallGroup>
```

### 3. 进度显示

**文件**: `components/chat/ProgressBar.tsx`

**功能**:
- 确定进度条（显示百分比）
- 不确定进度条（动画效果）
- 流式输出指示器（打字动画）
- 步骤进度展示（多步骤流程）

**使用示例**:
```tsx
import { ProgressBar, StreamingIndicator, StepProgress } from '@/components'

// 确定进度
<ProgressBar progress={45} text="处理进度: 45%" />

// 不确定进度
<ProgressBar indeterminate text="正在处理..." />

// 步骤进度
<StepProgress
  steps={[
    { id: '1', label: '分析需求', status: 'completed' },
    { id: '2', label: '执行操作', status: 'active' },
    { id: '3', label: '验证结果', status: 'pending' },
  ]}
/>

// 流式指示器
<StreamingIndicator streaming text="正在生成回答..." />
```

### 4. 思考过程可视化

**文件**: `components/chat/ThinkingBlock.tsx`

**功能**:
- 展开/折叠思考内容
- 打字动画效果（流式输出）
- 思考过程动画（脉冲效果）
- 显示思考内容的字数和预估阅读时间
- 自动解析和格式化思考内容
- 时间戳显示

**使用示例**:
```tsx
import { ThinkingBlock, ThinkingAnimation } from '@/components'

// 完整思考块
<ThinkingBlock
  content="用户想要创建一个移动端应用..."
  timestamp="2024-04-22 10:30:00"
/>

// 流式思考（正在思考）
<ThinkingBlock
  isStreaming
  timestamp="2024-04-22 10:35:00"
/>

// 思考动画组件
<ThinkingAnimation size={60} color="#6366f1" />
```

## 组件架构

```
components/
├── markdown/
│   ├── MarkdownRenderer.tsx    # Markdown 渲染器
│   └── Icons.tsx              # SVG 图标组件
├── chat/
│   ├── ToolCallBlock.tsx      # 工具调用可视化
│   ├── ProgressBar.tsx        # 进度显示
│   └── ThinkingBlock.tsx      # 思考过程可视化
├── MessageBubble.tsx           # 消息气泡（已更新）
└── index.ts                    # 组件导出
```

## 主题支持

所有组件都通过 `useTheme` hook 支持主题切换：
- 亮色模式
- 暗色模式
- 自定义主题色

## 演示页面

访问 `app/(tabs)/demo.tsx` 查看所有组件的实际效果。

## 下一步

建议的后续改进：
1. 集成 WebSocket 实时通信
2. 添加更多图标（使用 react-native-vector-icons）
3. 优化性能（虚拟化长列表）
4. 添加单元测试
5. 支持更多 Markdown 特性（表格、任务列表等）
6. 添加工具调用的历史记录
7. 实现思考内容的搜索功能
