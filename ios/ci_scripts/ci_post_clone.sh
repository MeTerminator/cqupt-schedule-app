#!/bin/sh

# Fail this script if any subcommand fails
set -e

# Navigate to the root of your cloned repository
cd "$CI_PRIMARY_REPOSITORY_PATH"

# 1. Clone the Flutter SDK (stable channel)
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

# 2. Pre-download Flutter artifacts for iOS
flutter precache --ios

# 3. Install Flutter project dependencies
flutter pub get

# 4. Sync Xcode project config (incl. Swift Package Manager deployment target
# fix-up for plugins like home_widget that require a higher iOS version than
# FlutterGeneratedPluginSwiftPackage's default). --config-only skips the
# actual compile since Xcode Cloud's own Archive action does that.
flutter build ios --release --no-codesign --config-only

# 5. Install CocoaPods and dependencies
HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods
cd ios
pod install --repo-update

exit 0
