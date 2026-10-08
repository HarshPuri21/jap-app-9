#!/usr/bin/env python3
"""Applies the Android configuration the notification subsystem needs to the
*generated* android/ project.

This repo intentionally does not commit android/ -- CI (and local builds, see
SETUP_INSTRUCTIONS.md) create it with `flutter create --platforms=android`.
Run this script from the project root right after that step:

    python3 tool/android/apply_notification_android_config.py

What it applies (see docs/notifications/INTEGRATION.md, sections 1, 3 and 4):

  * POST_NOTIFICATIONS and RECEIVE_BOOT_COMPLETED permissions
  * the three flutter_local_notifications receivers (action, scheduled, boot)
  * compileSdk >= 36, multiDex, Java 17 (source, target and Kotlin jvmTarget)
  * core library desugaring (flag + dependency)
  * the notification icon drawable
  * res/raw/keep.xml so release-build resource shrinking cannot strip the icon
    (the icon is referenced only by name from Dart, which the shrinker cannot
    see)

The script is idempotent: every edit is guarded by a presence check, so running
it twice changes nothing the second time. It never downgrades a newer value,
and it exits non-zero with a clear message if the generated project has a shape
it does not understand, rather than silently producing a broken build.
"""

import argparse
import re
import shutil
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

MIN_COMPILE_SDK = 36
JAVA_VERSION = 17
DESUGAR_COORDINATE = "com.android.tools:desugar_jdk_libs:2.1.4"
ICON_NAME = "ic_notification"

PERMISSIONS = [
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.RECEIVE_BOOT_COMPLETED",
]

PLUGIN_PACKAGE = "com.dexterous.flutterlocalnotifications"

RECEIVERS = {
    "ActionBroadcastReceiver": """\
        <receiver
            android:exported="false"
            android:name="{pkg}.ActionBroadcastReceiver" />
""",
    "ScheduledNotificationReceiver": """\
        <receiver
            android:exported="false"
            android:name="{pkg}.ScheduledNotificationReceiver" />
""",
    "ScheduledNotificationBootReceiver": """\
        <receiver
            android:exported="false"
            android:name="{pkg}.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON" />
            </intent-filter>
        </receiver>
""",
}

KEEP_XML = """\
<?xml version="1.0" encoding="utf-8"?>
<resources xmlns:tools="http://schemas.android.com/tools"
    tools:keep="@drawable/ic_notification" />
"""


class PatchError(Exception):
    """The generated project has a shape this script does not understand."""


def log(message):
    print(f"[notification-android] {message}")


# --------------------------------------------------------------------------
# AndroidManifest.xml
# --------------------------------------------------------------------------

def patch_manifest(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    original = text

    # Permissions: directly under <manifest>, before <application>.
    missing = [p for p in PERMISSIONS if f'android:name="{p}"' not in text]
    if missing:
        match = re.search(r"^([ \t]*)<application\b", text, re.MULTILINE)
        if not match:
            raise PatchError("AndroidManifest.xml has no <application> element.")
        indent = match.group(1)
        block = "".join(
            f'{indent}<uses-permission android:name="{p}" />\n' for p in missing
        )
        text = text[: match.start()] + block + text[match.start():]

    # Receivers: inside <application>, before its closing tag.
    missing_receivers = [
        name
        for name in RECEIVERS
        if f'android:name="{PLUGIN_PACKAGE}.{name}"' not in text
    ]
    if missing_receivers:
        close = text.rfind("</application>")
        if close == -1:
            raise PatchError(
                "AndroidManifest.xml has no closing </application> tag "
                "(self-closing <application/> is not supported)."
            )
        line_start = text.rfind("\n", 0, close) + 1
        block = "".join(
            RECEIVERS[name].format(pkg=PLUGIN_PACKAGE) for name in missing_receivers
        )
        text = text[:line_start] + block + text[line_start:]

    if text != original:
        path.write_text(text, encoding="utf-8")
    return text != original


def verify_manifest(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    try:
        ET.fromstring(text)
    except ET.ParseError as error:
        raise PatchError(f"AndroidManifest.xml is not well-formed: {error}")
    for permission in PERMISSIONS:
        if text.count(f'android:name="{permission}"') != 1:
            raise PatchError(f"Expected exactly one {permission} declaration.")
    for name in RECEIVERS:
        if text.count(f'android:name="{PLUGIN_PACKAGE}.{name}"') != 1:
            raise PatchError(f"Expected exactly one {name} declaration.")


# --------------------------------------------------------------------------
# app/build.gradle(.kts)
# --------------------------------------------------------------------------

def _below_min_java(token: str) -> bool:
    """True for '8', '1_8', '1.8', '11' ... i.e. anything older than 17."""
    token = token.replace("_", ".")
    if token.startswith("1."):
        return True  # 1.6 / 1.7 / 1.8
    return int(token.split(".")[0]) < JAVA_VERSION


def _bump_java_targets(text: str) -> str:
    def java_version(match):
        token = (match.group(1) or "") + match.group(2)
        if _below_min_java(token.replace("_", ".")):
            return f"JavaVersion.VERSION_{JAVA_VERSION}"
        return match.group(0)

    def jvm_target_enum(match):
        token = (match.group(1) or "") + match.group(2)
        if _below_min_java(token.replace("_", ".")):
            return f"JvmTarget.JVM_{JAVA_VERSION}"
        return match.group(0)

    def jvm_target_string(match):
        if _below_min_java(match.group(3)):
            return f"{match.group(1)}{match.group(2)}{JAVA_VERSION}{match.group(2)}"
        return match.group(0)

    text = re.sub(r"JavaVersion\.VERSION_(1_)?(\d+)", java_version, text)
    text = re.sub(r"JvmTarget\.JVM_(1_)?(\d+)", jvm_target_enum, text)
    text = re.sub(
        r"""(jvmTarget\s*=\s*)(["'])(\d+(?:\.\d+)?)\2""", jvm_target_string, text
    )
    return text


def _patch_compile_sdk(text: str, kts: bool) -> str:
    pattern = re.compile(
        r"^([ \t]*)(compileSdk(?:Version)?)([ \t]*=[ \t]*|[ \t]+)(.+?)[ \t]*$",
        re.MULTILINE,
    )
    match = pattern.search(text)
    if not match:
        raise PatchError("Could not find a compileSdk declaration in build file.")

    value = match.group(4)
    if re.fullmatch(r"\d+", value):
        if int(value) >= MIN_COMPILE_SDK:
            return text  # already new enough; never downgrade
        new_value = str(MIN_COMPILE_SDK)
    elif "flutter.compileSdkVersion" in value:
        if re.search(r"\b(max|maxOf|Math\.max)\b", value):
            return text  # already patched
        maximum = "maxOf" if kts else "Math.max"
        new_value = f"{maximum}(flutter.compileSdkVersion, {MIN_COMPILE_SDK})"
    else:
        raise PatchError(
            f"Unrecognised compileSdk expression: {value!r}. Set it to "
            f"{MIN_COMPILE_SDK} or higher by hand."
        )
    replacement = f"{match.group(1)}{match.group(2)}{match.group(3)}{new_value}"
    return text[: match.start()] + replacement + text[match.end():]


def _open_block(text: str, name: str):
    """Finds `name {` on its own line; returns (end_of_line_index, indent)."""
    match = re.search(rf"^([ \t]*){name}[ \t]*\{{[ \t]*$", text, re.MULTILINE)
    if not match:
        return None
    return match.end(), match.group(1)


def _insert_after_open(text: str, name: str, line: str, indent_extra="    "):
    found = _open_block(text, name)
    if not found:
        raise PatchError(f"Could not find a `{name} {{` block in build file.")
    end, indent = found
    return text[:end] + f"\n{indent}{indent_extra}{line}" + text[end:]


def patch_gradle(path: Path) -> bool:
    kts = path.suffix == ".kts"
    text = path.read_text(encoding="utf-8")
    original = text

    text = _patch_compile_sdk(text, kts)

    # multiDex
    if "multiDexEnabled" not in text:
        line = "multiDexEnabled = true" if kts else "multiDexEnabled true"
        text = _insert_after_open(text, "defaultConfig", line)

    # Java / Kotlin targets (never downgrade)
    text = _bump_java_targets(text)

    # Core library desugaring flag inside compileOptions
    if not re.search(r"[cC]oreLibraryDesugaringEnabled", text):
        flag = (
            "isCoreLibraryDesugaringEnabled = true"
            if kts
            else "coreLibraryDesugaringEnabled true"
        )
        if _open_block(text, "compileOptions"):
            text = _insert_after_open(text, "compileOptions", flag)
        else:
            # No compileOptions at all: create one at the top of `android {`.
            found = _open_block(text, "android")
            if not found:
                raise PatchError("Could not find an `android {` block.")
            end, indent = found
            sep = "=" if kts else ""
            pad = " " if kts else " "
            block = (
                f"\n\n{indent}    compileOptions {{\n"
                f"{indent}        {flag}\n"
                f"{indent}        sourceCompatibility{pad}{sep}{pad}"
                f"JavaVersion.VERSION_{JAVA_VERSION}\n"
                f"{indent}        targetCompatibility{pad}{sep}{pad}"
                f"JavaVersion.VERSION_{JAVA_VERSION}\n"
                f"{indent}    }}"
            )
            text = text[:end] + block + text[end:]

    # Desugaring dependency
    if "desugar_jdk_libs" not in text:
        dep = (
            f'coreLibraryDesugaring("{DESUGAR_COORDINATE}")'
            if kts
            else f"coreLibraryDesugaring '{DESUGAR_COORDINATE}'"
        )
        top_level = re.search(r"^dependencies[ \t]*\{[ \t]*$", text, re.MULTILINE)
        empty_inline = re.search(r"^dependencies[ \t]*\{[ \t]*\}[ \t]*$", text, re.MULTILINE)
        if top_level:
            text = text[: top_level.end()] + f"\n    {dep}" + text[top_level.end():]
        elif empty_inline:
            text = (
                text[: empty_inline.start()]
                + f"dependencies {{\n    {dep}\n}}"
                + text[empty_inline.end():]
            )
        else:
            if not text.endswith("\n"):
                text += "\n"
            text += f"\ndependencies {{\n    {dep}\n}}\n"

    if text != original:
        path.write_text(text, encoding="utf-8")
    return text != original


def verify_gradle(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    checks = {
        "core library desugaring flag": r"[cC]oreLibraryDesugaringEnabled",
        "desugaring dependency": r"desugar_jdk_libs",
        "multiDexEnabled": r"multiDexEnabled",
        f"Java >= {JAVA_VERSION} target": r"JavaVersion\.VERSION_(?:1[7-9]|[2-9]\d)",
    }
    for label, pattern in checks.items():
        if not re.search(pattern, text):
            raise PatchError(f"Verification failed: missing {label}.")
    for label, pattern in {
        "desugaring dependency": r"desugar_jdk_libs",
        "desugaring flag": r"[cC]oreLibraryDesugaringEnabled",
        "multiDexEnabled": r"multiDexEnabled",
    }.items():
        if len(re.findall(pattern, text)) != 1:
            raise PatchError(f"Verification failed: duplicate {label}.")
    if re.search(r"JavaVersion\.VERSION_(1_)?(?:[1-9]|1[0-6])\b", text):
        raise PatchError("Verification failed: a pre-17 Java version remains.")


# --------------------------------------------------------------------------
# Resources
# --------------------------------------------------------------------------

def install_icon(project_root: Path, res_dir: Path) -> bool:
    source = project_root / "tool" / "android" / "ic_notification.xml"
    if not source.is_file():
        raise PatchError(f"Icon source not found: {source}")
    target = res_dir / "drawable" / "ic_notification.xml"
    if target.is_file() and target.read_bytes() == source.read_bytes():
        return False
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
    return True


def install_keep_rules(res_dir: Path) -> bool:
    target = res_dir / "raw" / "keep.xml"
    keep_ref = f"@drawable/{ICON_NAME}"
    if not target.is_file():
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(KEEP_XML, encoding="utf-8")
        return True

    text = target.read_text(encoding="utf-8")
    if keep_ref in text:
        return False
    match = re.search(r'tools:keep="([^"]*)"', text)
    if not match:
        raise PatchError(
            f"{target} exists without a tools:keep attribute; add "
            f"{keep_ref} to it by hand."
        )
    merged = f'tools:keep="{match.group(1)},{keep_ref}"'
    target.write_text(text[: match.start()] + merged + text[match.end():], "utf-8")
    return True


# --------------------------------------------------------------------------

def find_build_file(app_dir: Path) -> Path:
    for name in ("build.gradle.kts", "build.gradle"):
        candidate = app_dir / name
        if candidate.is_file():
            return candidate
    raise PatchError(f"No build.gradle(.kts) found in {app_dir}.")


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument(
        "--project-dir",
        default=".",
        help="Flutter project root (contains pubspec.yaml and android/).",
    )
    args = parser.parse_args(argv)

    root = Path(args.project_dir).resolve()
    app_dir = root / "android" / "app"
    manifest = app_dir / "src" / "main" / "AndroidManifest.xml"
    res_dir = app_dir / "src" / "main" / "res"

    if not manifest.is_file():
        log(
            f"ERROR: {manifest} not found. Run "
            "`flutter create --platforms=android --org com.claire .` first."
        )
        return 1

    try:
        build_file = find_build_file(app_dir)
        results = {
            "AndroidManifest.xml": patch_manifest(manifest),
            build_file.name: patch_gradle(build_file),
            "drawable/ic_notification.xml": install_icon(root, res_dir),
            "raw/keep.xml": install_keep_rules(res_dir),
        }
        verify_manifest(manifest)
        verify_gradle(build_file)
    except PatchError as error:
        log(f"ERROR: {error}")
        return 1

    for name, changed in results.items():
        log(f"{name}: {'updated' if changed else 'already up to date'}")
    log("Android notification configuration is in place.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
