import { Redirect } from 'expo-router'
import { useAuthStore } from '@/stores/authStore'

export default function Index() {
  const { isLoggedIn, isHydrated } = useAuthStore()

  if (!isHydrated) {
    return null // Loading state
  }

  if (isLoggedIn) {
    return <Redirect href="/(tabs)/sessions" />
  }

  return <Redirect href="/(auth)/login" />
}
