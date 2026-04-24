import React from 'react'
import PixelMascot, { MascotStatus } from './PixelMascot'

export interface MascotWidgetProps {
  size?: number
  color?: string
  status?: MascotStatus
}

const DEFAULT_COLOR = '#DE886D'

/**
 * MascotWidget — 像素风格吉祥物组件
 * 用于 Tab 栏显示会话状态
 */
export const MascotWidget: React.FC<MascotWidgetProps> = ({
  size = 27,
  color = DEFAULT_COLOR,
  status = 'idle',
}) => {
  return (
    <PixelMascot
      size={size}
      color={color}
      status={status}
    />
  )
}

export default MascotWidget
