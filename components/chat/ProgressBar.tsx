import React from 'react'
import { View, StyleSheet, Animated, Text } from 'react-native'
import { useTheme } from '@/utils/theme'
import { Spinner } from '../markdown/Icons'

type ProgressBarProps = {
  progress?: number // 0-100
  text?: string
  indeterminate?: boolean
  color?: string
}

export function ProgressBar({
  progress = 0,
  text,
  indeterminate = false,
  color,
}: ProgressBarProps) {
  const { colors } = useTheme()
  const progressColor = color || colors.primary

  if (indeterminate) {
    return <IndeterminateProgressBar text={text} color={progressColor} />
  }

  return (
    <View style={styles.container}>
      <View style={[styles.track, { backgroundColor: colors.surface }]}>
        <Animated.View
          style={[
            styles.fill,
            {
              width: `${Math.min(Math.max(progress, 0), 100)}%`,
              backgroundColor: progressColor,
            },
          ]}
        />
      </View>
      {text && (
        <Text style={[styles.text, { color: colors.textSecondary }]}>
          {text}
        </Text>
      )}
    </View>
  )
}

type IndeterminateProgressBarProps = {
  text?: string
  color: string
}

function IndeterminateProgressBar({
  text,
  color,
}: IndeterminateProgressBarProps) {
  const { colors } = useTheme()
  const animatedValue = React.useRef(new Animated.Value(0)).current

  React.useEffect(() => {
    const animation = Animated.loop(
      Animated.sequence([
        Animated.timing(animatedValue, {
          toValue: 1,
          duration: 1500,
          useNativeDriver: true,
        }),
        Animated.timing(animatedValue, {
          toValue: 0,
          duration: 0,
          useNativeDriver: true,
        }),
      ])
    )
    animation.start()

    return () => animation.stop()
  }, [])

  const translateX = animatedValue.interpolate({
    inputRange: [0, 1],
    outputRange: [-200, 200],
  })

  return (
    <View style={styles.container}>
      <View style={[styles.track, styles.indeterminateTrack, { backgroundColor: colors.surface }]}>
        <Animated.View
          style={[
            styles.indeterminateFill,
            {
              backgroundColor: color,
              transform: [{ translateX }],
            },
          ]}
        />
      </View>
      {text && (
        <View style={styles.textContainer}>
          <Spinner size={20} color={colors.textSecondary} />
          <Text style={[styles.text, { color: colors.textSecondary }]}>
            {text}
          </Text>
        </View>
      )}
    </View>
  )
}

type StreamingIndicatorProps = {
  streaming: boolean
  text?: string
  active?: boolean
}

export function StreamingIndicator({ streaming, text, active }: StreamingIndicatorProps) {
  const { colors } = useTheme()
  const opacity1 = React.useRef(new Animated.Value(0.3)).current
  const opacity2 = React.useRef(new Animated.Value(0.3)).current
  const opacity3 = React.useRef(new Animated.Value(0.3)).current

  React.useEffect(() => {
    if (!streaming) return

    const createAnimation = (animatedValue: Animated.Value, delay: number) => {
      return Animated.loop(
        Animated.sequence([
          Animated.delay(delay),
          Animated.timing(animatedValue, {
            toValue: 1,
            duration: 400,
            useNativeDriver: true,
          }),
          Animated.timing(animatedValue, {
            toValue: 0.3,
            duration: 400,
            useNativeDriver: true,
          }),
        ])
      )
    }

    const animations = [
      createAnimation(opacity1, 0),
      createAnimation(opacity2, 150),
      createAnimation(opacity3, 300),
    ]

    animations.forEach((anim) => anim.start())

    return () => {
      animations.forEach((anim) => anim.stop())
    }
  }, [streaming])

  if (!streaming) return null

  return (
    <View style={[styles.streamingContainer, active && styles.streamingActive]}>
      <View style={styles.streamingDots}>
        <Animated.View style={[styles.dot, { backgroundColor: colors.primary, opacity: opacity1 }]} />
        <Animated.View style={[styles.dot, { backgroundColor: colors.primary, opacity: opacity2 }]} />
        <Animated.View style={[styles.dot, { backgroundColor: colors.primary, opacity: opacity3 }]} />
      </View>
      {text && (
        <Text style={[styles.streamingText, { color: colors.textSecondary }]}>
          {text}
        </Text>
      )}
    </View>
  )
}

type StepProgressProps = {
  steps: Array<{
    id: string
    label: string
    status: 'pending' | 'active' | 'completed' | 'error'
  }>
}

export function StepProgress({ steps }: StepProgressProps) {
  const { colors } = useTheme()

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'pending':
        return colors.textSecondary
      case 'active':
        return colors.primary
      case 'completed':
        return colors.success
      case 'error':
        return colors.error
    }
  }

  return (
    <View style={styles.stepsContainer}>
      {steps.map((step, index) => (
        <View key={step.id} style={styles.stepItem}>
          <View style={styles.stepHeader}>
            <View
              style={[
                styles.stepIndicator,
                {
                  backgroundColor: getStatusColor(step.status),
                  borderColor:
                    step.status === 'pending' ? colors.border : getStatusColor(step.status),
                },
              ]}
            >
              {step.status === 'completed' && (
                <Text style={styles.stepCheck}>✓</Text>
              )}
            </View>
            <Text
              style={[
                styles.stepLabel,
                {
                  color:
                    step.status === 'active' ? colors.text : colors.textSecondary,
                  fontWeight: step.status === 'active' ? '600' : '400',
                },
              ]}
            >
              {step.label}
            </Text>
          </View>
          {index < steps.length - 1 && (
            <View
              style={[
                styles.stepConnector,
                {
                  backgroundColor:
                    step.status === 'completed' ? colors.success : colors.border,
                },
              ]}
            />
          )}
        </View>
      ))}
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    gap: 8,
  },
  track: {
    height: 6,
    borderRadius: 3,
    overflow: 'hidden',
  },
  fill: {
    height: '100%',
    borderRadius: 3,
  },
  indeterminateTrack: {
    overflow: 'hidden',
  },
  indeterminateFill: {
    position: 'absolute',
    left: 0,
    top: 0,
    bottom: 0,
    width: 100,
  },
  text: {
    fontSize: 13,
    marginTop: 4,
  },
  textContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginTop: 4,
  },
  streamingContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    paddingVertical: 8,
    paddingHorizontal: 12,
    backgroundColor: 'rgba(0, 0, 0, 0.05)',
    borderRadius: 8,
    marginVertical: 8,
  },
  streamingActive: {
    backgroundColor: 'rgba(0, 0, 0, 0.08)',
  },
  streamingDots: {
    flexDirection: 'row',
    gap: 4,
  },
  dot: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  dotText: {
    fontSize: 12,
  },
  streamingText: {
    fontSize: 13,
  },
  stepsContainer: {
    gap: 4,
  },
  stepItem: {
    position: 'relative',
  },
  stepHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  stepIndicator: {
    width: 24,
    height: 24,
    borderRadius: 12,
    borderWidth: 2,
    alignItems: 'center',
    justifyContent: 'center',
  },
  stepCheck: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
  },
  stepLabel: {
    fontSize: 14,
  },
  stepConnector: {
    position: 'absolute',
    left: 11,
    top: 24,
    bottom: -16,
    width: 2,
  },
})
