const { getDefaultConfig } = require('expo/metro-config')

const config = getDefaultConfig(__dirname)

// Add support for @/* path alias
config.resolver.alias = {
  '@': '.',
}

// Ensure resolver can find files in all project directories
config.resolver.sourceExts = [
  'ts',
  'tsx',
  'js',
  'jsx',
  'json',
  'cjs',
]

module.exports = config
