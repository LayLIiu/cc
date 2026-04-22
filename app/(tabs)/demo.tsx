import React from 'react'
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  SafeAreaView,
  Platform,
} from 'react-native'
import {
  MarkdownRenderer,
  ToolCallBlock,
  ToolCallGroup,
  ProgressBar,
  StreamingIndicator,
  StepProgress,
  ThinkingBlock,
  ThinkingAnimation,
} from '@/components'

export default function DemoScreen() {
  const markdownContent = `# 示例 Markdown

这是一段**粗体**和*斜体*文本。

## 代码示例

\`\`\`typescript
function greet(name: string) {
  return \`Hello, \${name}!\`
}

const result = greet('World')
console.log(result)
\`\`\`

## 列表

- 第一项
- 第二项
- 第三项

## 链接

访问 [文档](https://example.com) 了解更多信息。

## 引用

> 这是一段引用文本，用于强调重要内容。
`

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView style={styles.scrollView}>
        <Text style={styles.title}>组件演示</Text>

        {/* Markdown 渲染 */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>1. Markdown 渲染</Text>
          <MarkdownRenderer content={markdownContent} />
        </View>

        {/* 工具调用可视化 */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>2. 工具调用可视化</Text>
          <ToolCallGroup title="文件操作">
            <ToolCallBlock
              toolName="Read"
              input={{
                file_path: "/path/to/file.ts",
                offset: 0,
                limit: 100,
              }}
              status="completed"
              result="文件内容..."
              timestamp="2024-04-22 10:30:00"
              duration={234}
            />
            <ToolCallBlock
              toolName="Write"
              input={{
                file_path: "/path/to/file.ts",
                content: "新内容",
              }}
              status="running"
            />
          </ToolCallGroup>
        </View>

        {/* 进度显示 */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>3. 进度显示</Text>

          <ProgressBar progress={45} text="处理进度: 45%" />
          <ProgressBar indeterminate text="正在处理..." />

          <View style={styles.stepProgress}>
            <StepProgress
              steps={[
                { id: '1', label: '分析需求', status: 'completed' },
                { id: '2', label: '执行操作', status: 'active' },
                { id: '3', label: '验证结果', status: 'pending' },
              ]}
            />
          </View>

          <StreamingIndicator streaming text="正在生成回答..." active />
        </View>

        {/* 思考过程 */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>4. 思考过程</Text>

          <ThinkingBlock
            content="用户想要创建一个移动端应用。我需要：
- 分析项目需求
- 设计技术架构
- 实现核心功能

首先，让我分析一下用户的具体需求..."
            timestamp="2024-04-22 10:30:00"
          />

          <ThinkingBlock
            isStreaming
            timestamp="2024-04-22 10:35:00"
          />
        </View>

        {/* 思考动画 */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>5. 思考动画</Text>
          <View style={styles.animationContainer}>
            <ThinkingAnimation size={60} />
          </View>
        </View>

        <View style={styles.spacer} />
      </ScrollView>
    </SafeAreaView>
  )
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
  },
  scrollView: {
    flex: 1,
  },
  title: {
    fontSize: 24,
    fontWeight: '700',
    paddingHorizontal: 16,
    paddingTop: 16,
    paddingBottom: 8,
  },
  section: {
    marginBottom: 24,
    paddingHorizontal: 16,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '600',
    marginBottom: 12,
  },
  stepProgress: {
    paddingVertical: 8,
  },
  animationContainer: {
    alignItems: 'center',
    paddingVertical: 16,
  },
  spacer: {
    height: 40,
  },
})
