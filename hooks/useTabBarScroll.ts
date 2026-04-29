import { useRef, useCallback } from 'react'
import { useSessionStore } from '@/stores/sessionStore'
import { useFocusEffect } from 'expo-router'

/**
 * 滚动联动 Tab 栏显示/隐藏
 * 下滑隐藏，上滑显示，页面获得焦点时恢复显示
 */
export function useTabBarScroll() {
  const setTabBarVisible = useSessionStore((s) => s.setTabBarVisible)
  const lastScrollY = useRef(0)

  // 页面获得焦点时恢复 Tab 栏
  useFocusEffect(
    useCallback(() => {
      setTabBarVisible(true)
      lastScrollY.current = 0
    }, [setTabBarVisible])
  )

  const handleScroll = useCallback((event: any) => {
    const currentY = event.nativeEvent.contentOffset.y
    const diff = currentY - lastScrollY.current
    if (Math.abs(diff) < 10) return
    lastScrollY.current = currentY
    // 下滑（diff > 0）隐藏，上滑（diff < 0）显示
    setTabBarVisible(diff < 0)
  }, [setTabBarVisible])

  return { handleScroll, scrollEventThrottle: 16 }
}
