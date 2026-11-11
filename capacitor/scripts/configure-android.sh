#!/usr/bin/env bash
# Richtet das erzeugte Android-Projekt ein (wird im GitHub-Ablauf nach „npx cap add android“ aufgerufen).
set -euo pipefail
cd "$(dirname "$0")/.."
M=android/app/src/main/AndroidManifest.xml
G=android/app/build.gradle
# Berechtigungen: Mikrofon (Vorlesen/Tasbīḥ, nur beim Antippen), ungefährer + genauer Standort (Gebetszeiten/Qibla)
for perm in RECORD_AUDIO MODIFY_AUDIO_SETTINGS ACCESS_COARSE_LOCATION ACCESS_FINE_LOCATION; do
  grep -q "android.permission.$perm\"" "$M" || sed -i "s#</manifest>#    <uses-permission android:name=\"android.permission.$perm\" />\n</manifest>#" "$M"
done
# Standort ist keine Pflicht-Hardware (sonst wird die App auf manchen Geräten ausgeblendet)
grep -q 'android.hardware.location' "$M" || sed -i 's#</manifest>#    <uses-feature android:name="android.hardware.location" android:required="false" />\n    <uses-feature android:name="android.hardware.microphone" android:required="false" />\n</manifest>#' "$M"
# Mitteilungs-Symbol
mkdir -p android/app/src/main/res/drawable
cp android-extra/ic_stat_lm.xml android/app/src/main/res/drawable/ic_stat_lm.xml
# Hintergrund hinter Status- und Navigationsleiste: dunkelblau wie die App (statt weißer Streifen)
mkdir -p android/app/src/main/res/values
cat > android/app/src/main/res/values/lm_colors.xml <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<resources><color name="lm_bg">#13285A</color></resources>
XML
S=android/app/src/main/res/values/styles.xml
python3 - "$S" <<'PY'
import re,sys
p=sys.argv[1]; s=open(p).read()
items='<item name="android:windowBackground">@color/lm_bg</item><item name="android:statusBarColor">@color/lm_bg</item><item name="android:navigationBarColor">@color/lm_bg</item><item name="android:windowLightStatusBar">false</item>'
s=re.sub(r'(<style name="AppTheme.NoActionBar"[^>]*>)', r'\1'+items, s, count=1)
open(p,'w').write(s)
PY
grep -c lm_bg "$S"
# Version
if [ -n "${BUILD_NUMBER:-}" ]; then
  sed -i -E "s/versionCode [0-9]+/versionCode $BUILD_NUMBER/; s/versionName \"[^\"]*\"/versionName \"${APP_VERSION:-1.0.0}\"/" "$G"
fi
# Signieren mit dem Upload-Schlüssel (nur wenn vorhanden – Pfad und Passwort kommen aus Umgebungsvariablen, nie aus Dateien im Repo)
cat >> "$G" <<'GRADLE'

android {
    signingConfigs {
        if (System.getenv("LM_KEYSTORE")) {
            upload {
                storeFile file(System.getenv("LM_KEYSTORE"))
                storeType "pkcs12"
                storePassword System.getenv("LM_KEYPASS")
                keyAlias "upload"
                keyPassword System.getenv("LM_KEYPASS")
            }
        }
    }
    buildTypes {
        release {
            if (System.getenv("LM_KEYSTORE")) { signingConfig signingConfigs.upload }
        }
    }
}
GRADLE
grep -E "versionCode|versionName|minSdk|targetSdk" "$G" android/variables.gradle 2>/dev/null || true
grep -c "uses-permission" "$M"
echo "Android-Projekt eingerichtet"
