import React from 'react'
import ClaudeLogo, { ClaudeLogoProps } from './ClaudeLogo'

export interface ClaudeLogoWidgetProps extends Omit<ClaudeLogoProps, 'mode'> {
  /** 强制指定动画模式，不指定则根据 chatStatus 自动判断 */
  forceMode?: 'idle' | 'thinking' | 'waiting'
  /** 聊天状态，用于自动判断动画模式 */
  chatStatus?: 'idle' | 'thinking' | 'tool_executing' | 'streaming' | 'permission_pending'
}

const IDLE_LOGO_COLOR = '#D97757'

/**
 * ClaudeLogoWidget — 戴安娜 Logo 包装组件
 *
 * 动画模式映射（auto 模式）：
 *  - idle     → 静态（默认/等待输入）
 *  - waiting  → 触手周期性呼吸收缩/展开（等待权限确认）
 *  - thinking → 触手螺旋旋转（正在思考/执行工具/生成中）
 */
export const ClaudeLogoWidget: React.FC<ClaudeLogoWidgetProps> = ({
  size = 40,
  color = IDLE_LOGO_COLOR,
  forceMode,
  chatStatus = 'idle',
}) => {
  // 根据 forceMode 或 chatStatus 决定动画模式
  const mode = React.useMemo(() => {
    if (forceMode) {
      return forceMode
    }

    // permission_pending → waiting 呼吸动画
    if (chatStatus === 'permission_pending') {
      return 'waiting'
    }

    // thinking / tool_executing / streaming → 螺旋旋转
    if (chatStatus === 'thinking' || chatStatus === 'tool_executing' || chatStatus === 'streaming') {
      return 'thinking'
    }

    // idle → 静态
    return 'idle'
  }, [forceMode, chatStatus])

  return (
    <ClaudeLogo
      size={size}
      color={color}
      mode={mode}
    />
  )
}

export default ClaudeLogoWidget
