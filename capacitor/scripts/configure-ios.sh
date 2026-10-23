#!/usr/bin/env bash
# Setzt Berechtigungstexte, Version und die Datenschutz-Datei im erzeugten iOS-Projekt.
set -euo pipefail
cd "$(dirname "$0")/.."
PL=ios/App/App/Info.plist
pb(){ /usr/libexec/PlistBuddy -c "$1" "$PL" 2>/dev/null || true; }
set_str(){ plutil -replace "$1" -string "$2" "$PL"; }   # plutil: Texte mit Apostroph (Qur'an) sind kein Problem
set_str NSMicrophoneUsageDescription "Little Muslim hört beim Vorlesen des Qur'an zu, damit es die gelesenen Wörter markieren und Fehler anzeigen kann. Die Erkennung läuft auf dem Gerät."
set_str NSLocationWhenInUseUsageDescription "Little Muslim nutzt deinen Standort, um die Gebetszeiten und die Qibla-Richtung für deinen Ort zu berechnen."
set_str NSSpeechRecognitionUsageDescription "Little Muslim nutzt die Spracherkennung, um beim Vorlesen des Qur'an die gelesenen Wörter zu erkennen."
set_str CFBundleDisplayName "Little Muslim"
plutil -replace ITSAppUsesNonExemptEncryption -bool NO "$PL"
pb "Delete :UISupportedInterfaceOrientations"; /usr/libexec/PlistBuddy -c "Add :UISupportedInterfaceOrientations array" "$PL"
for o in UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight; do /usr/libexec/PlistBuddy -c "Add :UISupportedInterfaceOrientations: string $o" "$PL"; done
# iPad: alle Ausrichtungen (Pflicht für Multitasking); iPhone + iPad
pb "Delete :UISupportedInterfaceOrientations~ipad"; /usr/libexec/PlistBuddy -c "Add :UISupportedInterfaceOrientations~ipad array" "$PL"
for o in UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight; do /usr/libexec/PlistBuddy -c "Add :UISupportedInterfaceOrientations~ipad: string $o" "$PL"; done
sed -i '' -E 's/TARGETED_DEVICE_FAMILY = "?[0-9,]+"?;/TARGETED_DEVICE_FAMILY = "1,2";/g' ios/App/App.xcodeproj/project.pbxproj
# Version: 1.0.<Build-Nummer>
if [ -n "${BUILD_NUMBER:-}" ]; then
  pb "Set :CFBundleVersion $BUILD_NUMBER"; pb "Set :CFBundleShortVersionString ${APP_VERSION:-1.0.0}"
  sed -i '' -E "s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = $BUILD_NUMBER;/g; s/MARKETING_VERSION = [0-9.]+;/MARKETING_VERSION = ${APP_VERSION:-1.0.0};/g" ios/App/App.xcodeproj/project.pbxproj
fi
# Datenschutz-Datei ins App-Ziel aufnehmen
cp ios-extra/PrivacyInfo.xcprivacy ios/App/App/PrivacyInfo.xcprivacy
ruby -e '
require "xcodeproj"
p = Xcodeproj::Project.open("ios/App/App.xcodeproj")
t = p.targets.find { |x| x.name == "App" }
g = p.main_group.find_subpath("App", false) || p.main_group
unless g.files.any? { |f| f.path == "PrivacyInfo.xcprivacy" }
  ref = g.new_file("PrivacyInfo.xcprivacy")
  t.add_resources([ref])
end
p.save'
plutil -lint "$PL" ios/App/App/PrivacyInfo.xcprivacy
for k in NSMicrophoneUsageDescription NSLocationWhenInUseUsageDescription NSSpeechRecognitionUsageDescription; do printf '%s: ' "$k"; plutil -extract "$k" raw "$PL"; done
echo "iOS-Projekt eingerichtet"
