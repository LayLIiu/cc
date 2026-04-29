import * as Notifications from 'expo-notifications'
import { Platform } from 'react-native'

// 配置通知处理
Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldPlaySound: true,
    shouldSetBadge: false,
  }),
})

/**
 * 请求通知权限
 */
export async function requestNotificationPermission(): Promise<boolean> {
  const { status: existingStatus } = await Notifications.getPermissionsAsync()
  let finalStatus = existingStatus

  if (existingStatus !== 'granted') {
    const { status } = await Notifications.requestPermissionsAsync()
    finalStatus = status
  }

  if (finalStatus !== 'granted') {
    console.log('通知权限未授予')
    return false
  }

  if (Platform.OS === 'android') {
    await Notifications.setNotificationChannelAsync('default', {
      name: '消息通知',
      importance: Notifications.AndroidImportance.HIGH,
      vibrationPattern: [0, 250, 250, 250],
      lightColor: '#6366f1',
    })
  }

  return true
}

/**
 * 发送对话完成通知
 * @param title 会话标题
 * @param message 最后一条消息内容（截断显示）
 */
export async function sendCompletionNotification(
  title: string,
  message: string
): Promise<void> {
  // 检查 app 是否在前台
  const appState = await Notifications.getExpoPushTokenAsync().catch(() => null)

  // 截断消息内容，最多显示 100 字符
  const truncatedMessage = message.length > 100
    ? message.slice(0, 100) + '...'
    : message

  await Notifications.scheduleNotificationAsync({
    content: {
      title: `✅ ${title || '对话完成'}`,
      body: truncatedMessage,
      sound: 'default',
    },
    trigger: null, // 立即发送
  })
}
