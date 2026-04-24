import { Redirect } from 'expo-router'
import { View, ActivityIndicator, StyleSheet } from 'react-native'
import { useAuthStore } from '@/stores/authStore'
import { useTheme } from '@/utils/theme'

export default function Index() {
  const { isLoggedIn, isHydrated } = useAuthStore()
  const { colors } = useTheme()

  // Show loading screen while hydrating from AsyncStorage
  if (!isHydrated) {
    return (
      <View style={[styles.loadingContainer, { backgroundColor: colors.background }]}>
        <ActivityIndicator size="large" color={colors.primary} />
      </View>
    )
  }

  if (isLoggedIn) {
    return <Redirect href="/(tabs)/sessions" />
  }

  return <Redirect href="/(auth)/login" />
}

const styles = StyleSheet.create({
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
})
