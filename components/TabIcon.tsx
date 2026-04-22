import { View, Text, StyleSheet } from 'react-native'

type TabIconProps = {
  icon: string
  label: string
  color: string
  focused: boolean
}

export function TabIcon({ icon, label, color, focused }: TabIconProps) {
  return (
    <View style={styles.container}>
      <Text style={[styles.icon, { fontSize: focused ? 26 : 24 }]}>
        {icon}
      </Text>
      <Text style={[styles.label, { color }]}>
        {label}
      </Text>
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    justifyContent: 'center',
    gap: 2,
  },
  icon: {
    lineHeight: 28,
  },
  label: {
    fontSize: 11,
    fontWeight: '500',
  },
})
