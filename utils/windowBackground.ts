import { NativeModules, Platform } from 'react-native'

/**
 * 设置 Android 原生窗口背景色，解决深色模式下页面跳转白色闪烁问题
 */
export function setWindowBackground(color: string) {
  if (Platform.OS === 'android') {
    try {
      NativeModules.WindowBackground?.setColor(color)
    } catch {
      // 模块未注册时忽略
    }
  }
}
