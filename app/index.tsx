import { Redirect } from 'expo-router'
import { View, ActivityIndicator, StyleSheet } from 'react-native'
import { useAuthStore } from '@/stores/authStore'

export default function Index() {
  const { isLoggedIn, isHydrated } = useAuthStore()

  // Show loading screen while hydrating from AsyncStorage
  if (!isHydrated) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#007AFF" />
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
    backgroundColor: '#fff',
  },
})
