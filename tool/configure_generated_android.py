from __future__ import annotations

import os
import re
from pathlib import Path

PACKAGE = "com.STEALTHE.QUESTIONSSX1"

app_gradle = Path("android/app/build.gradle.kts")
settings_gradle = Path("android/settings.gradle.kts")

if not app_gradle.exists() or not settings_gradle.exists():
    raise SystemExit("Generated Android project was not found.")

app = app_gradle.read_text(encoding="utf-8")
settings = settings_gradle.read_text(encoding="utf-8")

app = re.sub(r'namespace\s*=\s*"[^"]+"', f'namespace = "{PACKAGE}"', app)
app = re.sub(r'applicationId\s*=\s*"[^"]+"', f'applicationId = "{PACKAGE}"', app)


# flutter create generates MainActivity under the template package.
# When applicationId/namespace are changed afterwards, Android resolves
# ".MainActivity" against the new namespace. Keep the Kotlin package in sync
# or the release APK launches into a blank/crashed activity.
main_activities = list(Path("android/app/src/main/kotlin").rglob("MainActivity.kt"))
if not main_activities:
    raise SystemExit("MainActivity.kt was not generated.")

for activity_path in main_activities:
    source = activity_path.read_text(encoding="utf-8")
    source = re.sub(
        r"^package\s+[^\n]+",
        f"package {PACKAGE}",
        source,
        count=1,
        flags=re.MULTILINE,
    )
    activity_path.write_text(source, encoding="utf-8")

# Release Firebase/Functions/Google authentication requires network access.
manifest_path = Path("android/app/src/main/AndroidManifest.xml")
manifest = manifest_path.read_text(encoding="utf-8")
if "android.permission.INTERNET" not in manifest:
    manifest = manifest.replace(
        "<manifest xmlns:android=\"http://schemas.android.com/apk/res/android\">",
        "<manifest xmlns:android=\"http://schemas.android.com/apk/res/android\">\n"
        '    <uses-permission android:name="android.permission.INTERNET"/>',
        1,
    )
manifest_path.write_text(manifest, encoding="utf-8")

google_services = Path("android/app/google-services.json").exists()
if google_services:
    if 'id("com.google.gms.google-services")' not in settings:
        settings = settings.replace(
            'id("org.jetbrains.kotlin.android")',
            'id("com.google.gms.google-services") version "4.4.4" apply false\n    id("org.jetbrains.kotlin.android")',
            1,
        )
    if 'id("com.google.gms.google-services")' not in app:
        app = app.replace(
            'id("dev.flutter.flutter-gradle-plugin")',
            'id("dev.flutter.flutter-gradle-plugin")\n    id("com.google.gms.google-services")',
            1,
        )

store_file = os.getenv("ANDROID_RELEASE_STORE_FILE", "").strip()
store_password = os.getenv("ANDROID_KEYSTORE_PASSWORD", "").strip()
key_alias = os.getenv("ANDROID_KEY_ALIAS", "").strip()
key_password = os.getenv("ANDROID_KEY_PASSWORD", "").strip()

if all((store_file, store_password, key_alias, key_password)):
    signing_block = f'''
    signingConfigs {{
        create("release") {{
            storeFile = file("{store_file}")
            storePassword = "{store_password}"
            keyAlias = "{key_alias}"
            keyPassword = "{key_password}"
        }}
    }}
'''
    if 'create("release")' not in app:
        app = app.replace("android {", "android {" + signing_block, 1)
    app = app.replace(
        'signingConfig = signingConfigs.getByName("debug")',
        'signingConfig = signingConfigs.getByName("release")',
    )

app_gradle.write_text(app, encoding="utf-8")
settings_gradle.write_text(settings, encoding="utf-8")

print(f"Android applicationId configured as {PACKAGE}")
print(f"MainActivity package synchronized as {PACKAGE}")
print("Release INTERNET permission: enabled")
print(f"Firebase native config: {'enabled' if google_services else 'missing'}")
print(
    "Release signing: "
    + ("enabled" if all((store_file, store_password, key_alias, key_password)) else "debug fallback")
)
