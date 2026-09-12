const { getDefaultConfig } = require('expo/metro-config');

const config = getDefaultConfig(__dirname);

if (!config.resolver.assetExts.includes('pte')) {
  config.resolver.assetExts.push('pte');
}

module.exports = config;
