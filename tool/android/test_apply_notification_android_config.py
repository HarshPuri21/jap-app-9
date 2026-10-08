#!/usr/bin/env python3
"""Tests for apply_notification_android_config.py.

Runs the script against simulated `flutter create` output and checks that it
produces the required configuration, is byte-for-byte idempotent, and never
downgrades values that are already newer.

    python3 tool/android/test_apply_notification_android_config.py
"""

import re
import shutil
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import apply_notification_android_config as patcher  # noqa: E402

MANIFEST = """\
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="nihongo_trainer"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>
</manifest>
"""

KTS_MODERN = """\
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.claire.nihongo_trainer"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.claire.nihongo_trainer"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
"""

KTS_ENUM_TARGET_OLD_SDK = KTS_MODERN.replace(
    "compileSdk = flutter.compileSdkVersion", "compileSdk = 34"
).replace(
    'kotlinOptions {\n        jvmTarget = JavaVersion.VERSION_11.toString()\n    }',
    "kotlin {\n        compilerOptions {\n"
    "            jvmTarget = JvmTarget.JVM_11\n        }\n    }",
)

KTS_ALREADY_NEWER = (
    KTS_MODERN.replace("compileSdk = flutter.compileSdkVersion", "compileSdk = 37")
    .replace("VERSION_11", "VERSION_21")
)

GROOVY_OLD = """\
plugins {
    id "com.android.application"
    id "kotlin-android"
    id "dev.flutter.flutter-gradle-plugin"
}

android {
    namespace "com.claire.nihongo_trainer"
    compileSdkVersion flutter.compileSdkVersion
    ndkVersion flutter.ndkVersion

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = '1.8'
    }

    defaultConfig {
        applicationId "com.claire.nihongo_trainer"
        minSdkVersion flutter.minSdkVersion
        targetSdkVersion flutter.targetSdkVersion
        versionCode flutter.versionCode
        versionName flutter.versionName
    }
}

flutter {
    source "../.."
}

dependencies {}
"""

GROOVY_NEW = GROOVY_OLD.replace(
    "compileSdkVersion flutter.compileSdkVersion",
    "compileSdk = flutter.compileSdkVersion",
).replace("VERSION_1_8", "VERSION_11").replace("jvmTarget = '1.8'", "jvmTarget = '11'")

KTS_NO_COMPILE_OPTIONS = re.sub(
    r"    compileOptions \{.*?\n    \}\n\n", "", KTS_MODERN, flags=re.S
)


class PatcherTest(unittest.TestCase):
    def make_project(self, build_name: str, build_text: str) -> Path:
        root = Path(tempfile.mkdtemp(prefix="nihongo_android_"))
        self.addCleanup(shutil.rmtree, root, ignore_errors=True)
        (root / "tool" / "android").mkdir(parents=True)
        shutil.copyfile(
            HERE / "ic_notification.xml",
            root / "tool" / "android" / "ic_notification.xml",
        )
        app = root / "android" / "app"
        (app / "src" / "main" / "res" / "drawable").mkdir(parents=True)
        (app / "src" / "main" / "AndroidManifest.xml").write_text(MANIFEST)
        (app / build_name).write_text(build_text)
        return root

    def run_patcher(self, root: Path) -> int:
        return patcher.main(["--project-dir", str(root)])

    def snapshot(self, root: Path) -> dict:
        return {
            str(p.relative_to(root)): p.read_bytes()
            for p in sorted((root / "android").rglob("*"))
            if p.is_file()
        }

    def assert_fully_configured(self, root: Path, build_name: str):
        app = root / "android" / "app"
        manifest = (app / "src" / "main" / "AndroidManifest.xml").read_text()
        ET.fromstring(manifest)  # well-formed
        for name in (
            "POST_NOTIFICATIONS",
            "RECEIVE_BOOT_COMPLETED",
        ):
            self.assertEqual(manifest.count(f"android.permission.{name}"), 1)
        for name in patcher.RECEIVERS:
            self.assertEqual(
                manifest.count(f"{patcher.PLUGIN_PACKAGE}.{name}"), 1, name
            )
        # Receivers must sit inside <application>.
        self.assertLess(
            manifest.index("ScheduledNotificationBootReceiver"),
            manifest.index("</application>"),
        )
        # The existing activity/intent-filter is untouched.
        self.assertIn('android:name=".MainActivity"', manifest)
        self.assertIn("<queries>", manifest)

        gradle = (app / build_name).read_text()
        self.assertEqual(len(re.findall("desugar_jdk_libs", gradle)), 1)
        self.assertEqual(len(re.findall("[cC]oreLibraryDesugaringEnabled", gradle)), 1)
        self.assertEqual(gradle.count("multiDexEnabled"), 1)
        self.assertNotRegex(gradle, r"JavaVersion\.VERSION_(1_)?(?:[1-9]|1[0-6])\b")
        self.assertNotRegex(gradle, r"JvmTarget\.JVM_(1_)?(?:[1-9]|1[0-6])\b")
        self.assertNotRegex(gradle, r"jvmTarget\s*=\s*['\"](?:1\.\d|\d|1[0-6])['\"]")

        res = app / "src" / "main" / "res"
        self.assertEqual(
            (res / "drawable" / "ic_notification.xml").read_bytes(),
            (HERE / "ic_notification.xml").read_bytes(),
        )
        self.assertIn(
            "@drawable/ic_notification", (res / "raw" / "keep.xml").read_text()
        )

    def check_idempotent(self, build_name: str, build_text: str) -> Path:
        root = self.make_project(build_name, build_text)
        self.assertEqual(self.run_patcher(root), 0)
        self.assert_fully_configured(root, build_name)
        first = self.snapshot(root)
        self.assertEqual(self.run_patcher(root), 0)
        self.assertEqual(self.snapshot(root), first, "second run changed files")
        self.assertEqual(self.run_patcher(root), 0)
        self.assertEqual(self.snapshot(root), first, "third run changed files")
        return root

    def gradle_text(self, root: Path, build_name: str) -> str:
        return (root / "android" / "app" / build_name).read_text()

    # -- variants ---------------------------------------------------------

    def test_kotlin_dsl_modern_template(self):
        root = self.check_idempotent("build.gradle.kts", KTS_MODERN)
        text = self.gradle_text(root, "build.gradle.kts")
        self.assertIn("maxOf(flutter.compileSdkVersion, 36)", text)
        self.assertIn("isCoreLibraryDesugaringEnabled = true", text)
        self.assertIn('coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")', text)
        self.assertIn("jvmTarget = JavaVersion.VERSION_17.toString()", text)

    def test_kotlin_dsl_enum_jvm_target_and_old_literal_sdk(self):
        root = self.check_idempotent("build.gradle.kts", KTS_ENUM_TARGET_OLD_SDK)
        text = self.gradle_text(root, "build.gradle.kts")
        self.assertIn("compileSdk = 36", text)
        self.assertIn("JvmTarget.JVM_17", text)

    def test_newer_values_are_never_downgraded(self):
        root = self.check_idempotent("build.gradle.kts", KTS_ALREADY_NEWER)
        text = self.gradle_text(root, "build.gradle.kts")
        self.assertIn("compileSdk = 37", text)
        self.assertIn("VERSION_21", text)
        self.assertNotIn("VERSION_17", text.replace("VERSION_21", ""))

    def test_groovy_old_template(self):
        root = self.check_idempotent("build.gradle", GROOVY_OLD)
        text = self.gradle_text(root, "build.gradle")
        self.assertIn("Math.max(flutter.compileSdkVersion, 36)", text)
        self.assertIn("coreLibraryDesugaringEnabled true", text)
        self.assertIn("jvmTarget = '17'", text)
        # An existing empty top-level dependencies {} block is reused, not duplicated.
        self.assertEqual(len(re.findall(r"^dependencies", text, re.M)), 1)

    def test_groovy_new_template(self):
        root = self.check_idempotent("build.gradle", GROOVY_NEW)
        self.assertIn(
            "compileSdk = Math.max(flutter.compileSdkVersion, 36)",
            self.gradle_text(root, "build.gradle"),
        )

    def test_missing_compile_options_block_is_created(self):
        self.assertNotIn("compileOptions", KTS_NO_COMPILE_OPTIONS)
        root = self.check_idempotent("build.gradle.kts", KTS_NO_COMPILE_OPTIONS)
        self.assertIn("compileOptions {", self.gradle_text(root, "build.gradle.kts"))

    def test_existing_keep_xml_is_merged_not_replaced(self):
        root = self.make_project("build.gradle.kts", KTS_MODERN)
        raw = root / "android" / "app" / "src" / "main" / "res" / "raw"
        raw.mkdir(parents=True)
        (raw / "keep.xml").write_text(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<resources xmlns:tools="http://schemas.android.com/tools"\n'
            '    tools:keep="@raw/something" />\n'
        )
        self.assertEqual(self.run_patcher(root), 0)
        text = (raw / "keep.xml").read_text()
        self.assertIn("@raw/something", text)
        self.assertEqual(text.count("@drawable/ic_notification"), 1)
        first = self.snapshot(root)
        self.assertEqual(self.run_patcher(root), 0)
        self.assertEqual(self.snapshot(root), first)

    def test_partially_configured_manifest_only_gets_what_is_missing(self):
        root = self.make_project("build.gradle.kts", KTS_MODERN)
        manifest = root / "android/app/src/main/AndroidManifest.xml"
        text = manifest.read_text().replace(
            "    <application",
            '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />\n'
            "    <application",
            1,
        )
        manifest.write_text(text)
        self.assertEqual(self.run_patcher(root), 0)
        self.assert_fully_configured(root, "build.gradle.kts")

    def test_fails_loudly_without_a_generated_project(self):
        empty = Path(tempfile.mkdtemp(prefix="nihongo_empty_"))
        self.addCleanup(shutil.rmtree, empty, ignore_errors=True)
        self.assertEqual(self.run_patcher(empty), 1)

    def test_fails_loudly_on_unrecognised_compile_sdk(self):
        weird = KTS_MODERN.replace(
            "compileSdk = flutter.compileSdkVersion", "compileSdk = someCustomThing()"
        )
        root = self.make_project("build.gradle.kts", weird)
        self.assertEqual(self.run_patcher(root), 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
