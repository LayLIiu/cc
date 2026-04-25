import { View, Text, StyleSheet, ScrollView } from 'react-native'
import { useTheme } from '@/utils/theme'

// 版本更新日志
const CHANGELOG = [
  {
    version: '1.3.0',
    date: '2026-04-25',
    changes: [
      '新增配对码生成功能，快速连接桌面端',
      '新增网络信息显示（局域网 IP、隧道状态）',
      '新增隧道开关请求（远程开启/关闭公网访问）',
      '新增问题选择功能，支持选项和文字回答',
      '修复公网隧道连接 CORS 被拒问题',
      '优化 API 路径统一使用 /api/mobile/ 前缀',
    ],
  },
  {
    version: '1.2.6',
    date: '2026-04-24',
    changes: [
      '修复"已完成"状态一秒就切换的问题',
      '确保 completed 状态保持 1 分钟后才变为 idle',
      '修复全局状态检查使用旧值的闭包问题',
      '忽略 completed 状态下的 idle 消息',
    ],
  },
  {
    version: '1.2.5',
    date: '2026-04-24',
    changes: [
      '新增上下文容量圆形进度指示器',
      '显示在工作状态右边，颜色根据使用量变化',
      '支持服务器端推送真实数据（token_usage消息）',
      '工作过程中模拟显示容量使用变化',
    ],
  },
  {
    version: '1.2.4',
    date: '2026-04-24',
    changes: [
      '修复工作状态仍然会闪烁的问题',
      '全局状态订阅跳过当前聊天页面',
      '统一由 status 消息处理状态更新',
      '避免本地和全局状态更新冲突',
    ],
  },
  {
    version: '1.2.3',
    date: '2026-04-24',
    changes: [
      '修复工作状态错误显示等待中的问题',
      '优化全局状态防抖机制',
      '修复依赖数组缺少关键依赖的问题',
      '确保收到内容时状态正确更新',
    ],
  },
  {
    version: '1.2.2',
    date: '2026-04-24',
    changes: [
      '修复工作状态闪烁问题，添加防抖机制',
      '优化状态切换逻辑，更稳定显示工作状态',
      '新增版本更新日志功能',
    ],
  },
  {
    version: '1.2.1',
    date: '2026-04-24',
    changes: [
      '修复 Tab 栏键盘弹出时位置跳动问题',
      '修复聊天界面状态文字位置不固定问题',
      '优化吉祥物动画速度稳定性',
    ],
  },
  {
    version: '1.2.0',
    date: '2026-04-24',
    changes: [
      '新增"已完成"状态，AI 完成后显示庆祝动画',
      '已完成后 1 分钟自动变为等待中',
      '新增像素风格吉祥物庆祝动画',
      '优化状态管理逻辑',
    ],
  },
  {
    version: '1.1.0',
    date: '2026-04-23',
    changes: [
      '对话列表头像改为像素风格吉祥物',
      '每个对话显示不同颜色的吉祥物',
      '服务商 Tab 添加配对码和网络设置',
      'Tab 栏添加白色边框增加层次感',
      '修复会话列表状态不更新问题',
    ],
  },
  {
    version: '1.0.0',
    date: '2026-04-20',
    changes: [
      '首次发布',
      '支持连接 Claude Code 桌面端',
      '支持多服务商配置',
      '支持主题切换',
      '支持对话导入导出',
    ],
  },
]

export default function ChangelogScreen() {
  const { colors } = useTheme()

  return (
    <ScrollView
      style={[styles.container, { backgroundColor: colors.background }]}
      contentContainerStyle={styles.content}
    >
      {CHANGELOG.map((log, index) => (
        <View key={log.version} style={styles.versionBlock}>
          <View style={styles.versionHeader}>
            <Text style={[styles.versionNumber, { color: colors.primary }]}>
              v{log.version}
            </Text>
            <Text style={[styles.versionDate, { color: colors.textTertiary }]}>
              {log.date}
            </Text>
          </View>
          <View style={[styles.changesCard, { backgroundColor: colors.surface }]}>
            {log.changes.map((change, i) => (
              <View key={i} style={styles.changeItem}>
                <View style={[styles.bullet, { backgroundColor: colors.primary }]} />
                <Text style={[styles.changeText, { color: colors.textSecondary }]}>
                  {change}
                </Text>
              </View>
            ))}
          </View>
        </View>
      ))}

      <Text style={[styles.footer, { color: colors.textTertiary }]}>
        感谢使用 Claude Code Mobile
      </Text>
    </ScrollView>
  )
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  content: {
    padding: 16,
    paddingBottom: 40,
  },
  versionBlock: {
    marginBottom: 24,
  },
  versionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  versionNumber: {
    fontSize: 20,
    fontWeight: '700',
  },
  versionDate: {
    fontSize: 14,
  },
  changesCard: {
    borderRadius: 12,
    padding: 16,
  },
  changeItem: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    marginBottom: 12,
  },
  bullet: {
    width: 6,
    height: 6,
    borderRadius: 3,
    marginTop: 7,
    marginRight: 12,
  },
  changeText: {
    flex: 1,
    fontSize: 15,
    lineHeight: 22,
  },
  footer: {
    textAlign: 'center',
    marginTop: 24,
    fontSize: 14,
  },
})
