#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT/store_master_offline"
flutter create --platforms=android,windows --project-name store_master . --no-pub
cd "$ROOT/store_master_admin"
flutter create --platforms=windows --project-name store_master_admin . --no-pub
cd "$ROOT/store_master_offline"
if [ -f android/app/build.gradle ]; then sed -i -E 's/com\.example\.store_master(_offline)?/com.angelgirlbrand.store_master/g' android/app/build.gradle; fi
if [ -f android/app/build.gradle.kts ]; then sed -i -E 's/com\.example\.store_master(_offline)?/com.angelgirlbrand.store_master/g' android/app/build.gradle.kts; fi
python3 - <<'PY'
from pathlib import Path
p=Path('android/app/src/main/AndroidManifest.xml')
if p.exists():
    s=p.read_text()
    if 'android.permission.INTERNET' not in s:
        s=s.replace('>', '>\n    <uses-permission android:name="android.permission.INTERNET" />', 1)
        p.write_text(s)
PY
printf '%s\n' 'Platforms generated: Android + Windows client, Windows admin.'
