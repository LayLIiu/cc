import { useEffect } from 'react'
import { View, StyleSheet, TouchableOpacity, BackHandler } from 'react-native'
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  withSpring,
  runOnJS,
} from 'react-native-reanimated'

interface AnimatedModalProps {
  visible: boolean
  onClose: () => void
  children: React.ReactNode
}

const AnimatedModal: React.FC<AnimatedModalProps> = ({ visible, onClose, children }) => {
  const opacity = useSharedValue(0)
  const scale = useSharedValue(0.9)

  useEffect(() => {
    if (visible) {
      opacity.value = withTiming(1, { duration: 200 })
      scale.value = withSpring(1, { damping: 20, stiffness: 300 })
    } else {
      opacity.value = withTiming(0, { duration: 150 })
      scale.value = withTiming(0.9, { duration: 150 })
    }
  }, [visible])

  useEffect(() => {
    const backHandler = BackHandler.addEventListener('hardwareBackPress', () => {
      if (visible) {
        onClose()
        return true
      }
      return false
    })
    return () => backHandler.remove()
  }, [visible, onClose])

  const overlayStyle = useAnimatedStyle(() => ({
    opacity: opacity.value,
  }))

  const contentStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
    opacity: opacity.value,
  }))

  if (!visible) {
    return null
  }

  return (
    <View style={styles.container}>
      <Animated.View style={[styles.overlay, overlayStyle]}>
        <TouchableOpacity
          style={StyleSheet.absoluteFill}
          activeOpacity={1}
          onPress={onClose}
        />
      </Animated.View>
      <Animated.View style={[styles.contentWrapper, contentStyle]}>
        {children}
      </Animated.View>
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    ...StyleSheet.absoluteFillObject,
    justifyContent: 'center',
    alignItems: 'center',
    zIndex: 1000,
    elevation: 1000,
  },
  overlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
  },
  contentWrapper: {
    width: '90%',
    maxWidth: 400,
  },
})

export default AnimatedModal
