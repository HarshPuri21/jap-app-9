# Building Nihongo Trainer into an installable APK

## Why you need to do this step at all

Building an Android app requires Google's Android SDK. I build inside a
sandboxed environment with no access to Google's (or Codemagic's, or
FlutLab's, or any other build service's) servers, so I can't hand you a
finished `.apk` directly — but I *can* hand you a setup that builds itself
automatically, for free, the moment you upload it. That's Option A below,
and for most people it's genuinely easier than installing anything.

---

## Option A — Let GitHub build it for you (no install, ~10 minutes, recommended)

This repo already includes a GitHub Actions workflow
(`.github/workflows/build_apk.yml`) that does the entire build — Flutter,
Android SDK, everything — on GitHub's own servers. You just need to get
the code onto GitHub; nothing installs on your computer or phone until
you're downloading the finished APK.

1. **Create a free GitHub account** at github.com, if you don't have one.

2. **Create a new repository.** Click the `+` in the top-right → *New
   repository*. Name it `nihongo-trainer` (or anything), keep it
   **Private** if you'd like, and click *Create repository*. Don't add a
   README/gitignore when prompted — leave it empty.

3. **Upload the project.** On the new repo's page, click
   *"uploading an existing file"* (or *Add file → Upload files*).

   **Important:** open the unzipped `nihongo_trainer` folder, select
   *everything inside it* (`pubspec.yaml`, `lib`, `assets`, `.github`,
   `README.md`, `SETUP_INSTRUCTIONS.md` — select-all inside the folder),
   and drag *those* into the browser window. Don't drag the
   `nihongo_trainer` folder itself — that would nest everything one level
   too deep and the build wouldn't find `pubspec.yaml`. `pubspec.yaml`
   needs to land at the **root** of the repo.
   - Hidden folders like `.github` sometimes don't show up in a Finder/
     Explorer drag-select. If yours doesn't, the reliable alternative is
     **GitHub Desktop** (a small, no-terminal app) — open it, point it at
     the `nihongo_trainer` folder, and use "publish repository". It
     uploads everything, hidden files included, with correct structure
     every time.
   - Commit the upload (the button at the bottom of the page).

4. **Watch it build.** Click the **Actions** tab at the top of your repo.
   You should see a workflow run start automatically (titled "Build
   Android APK"). Click into it — it takes about 5–8 minutes. A green
   checkmark means it succeeded.

5. **Download the APK.** Still on that finished run's page, scroll down to
   **Artifacts** and click `nihongo-trainer-apk` to download a zip
   containing your `app-release.apk`.

6. **Get it onto your phone and install it** — see
   [Installing the APK](#installing-the-apk-on-your-oneplus-nord-6) below.

**To rebuild later** (e.g. after a future update): just upload the changed
file(s) through the same GitHub web page (Add file → Upload files) and
commit — the Action reruns automatically, and a new APK is waiting in
Actions → (latest run) → Artifacts a few minutes later.

**If the Action shows a red ✗:** click into the failed step to see the
error, and paste it back to me — I can usually spot the fix immediately
even without being able to run it myself.

---

## Option B — Build it locally instead

If you'd rather build on your own computer (e.g. so you can use
`flutter run` for live-reload while you tweak things), this works exactly
the same way, just on your machine instead of GitHub's:

### 1. Install Flutter
Go to `docs.flutter.dev/get-started/install` and follow the installer for
your OS (pick the **stable** channel). It will offer to install the
Android SDK for you.

Then:
```bash
flutter doctor --android-licenses
flutter doctor
```
Say `y` to every license prompt. Only the Android toolchain line needs a
green checkmark — ignore any Xcode/Chrome warnings.

### 2. Add Android support
Unzip this project, open a terminal **inside the folder**, and run:
```bash
flutter create --platforms=android --org com.claire .
flutter pub get
```
This only *adds* the `android/` folder Flutter needs — it won't touch the
`lib/`, `assets/`, or `pubspec.yaml` already here.

Then apply the Android settings the study-reminders feature needs (manifest
entries, Java 17 / desugaring, notification icon). It is safe to run more than
once, and GitHub builds (Option A) do this step automatically:
```bash
python3 tool/android/apply_notification_android_config.py
```

### 3. Generate the launcher icon
```bash
flutter pub run flutter_launcher_icons
```
Want your own image instead of the default "文" icon? Replace
`assets/icon/app_icon.png` and `assets/icon/app_icon_foreground.png`
(1024×1024 PNG, the foreground one transparent) and re-run the command
above — that's the only step needed.

### 4. Set the display name (optional)
In `android/app/src/main/AndroidManifest.xml`, change:
```xml
android:label="nihongo_trainer"
```
to whatever you'd like shown under the icon, e.g. `"Nihongo Trainer"`.

### 5. Build
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk` — already signed
and ready to install (Flutter uses a debug key automatically for this;
no extra setup needed for personal sideloading).

---

## Installing the APK on your OnePlus Nord 6

**Fastest — USB cable, skips manual file transfer entirely** (only
possible with Option B, since it needs the Flutter command on your
computer):
1. Settings → About Phone → tap "Build number" 7 times to unlock Developer
   Options.
2. In Developer Options, turn on **USB debugging**.
3. Plug the phone in, allow the USB debugging prompt.
4. Run `flutter install` — builds and installs directly, no file copying.

**Works with either option — copy the file over:**
1. Get `app-release.apk` onto your phone (USB transfer, Google Drive,
   emailing it to yourself, whatever's easiest).
2. Open it on your phone with a Files app and tap it.
3. Android will ask to allow "install unknown apps" from whichever app you
   opened it with — allow it, just for this install.
4. Tap **Install**.

Either way: the app installs like any other, shows up in your app drawer
and home screen, opens full-screen, appears in Settings → Apps, and
uninstalls the normal way.

---

## What's actually in this project

```
.github/workflows/build_apk.yml   builds the APK automatically on GitHub (Option A)
lib/
  main.dart                       entry point, loads data, sets up theming, wires providers
  theme/app_theme.dart            colors & text styles (matches the desktop app)
  models/
    sentence.dart, kanji_question.dart, vocab_entry.dart, kanji_entry.dart,
    radical_entry.dart, radical_question.dart
                                   typed wrappers around the JSON data
    item_progress.dart            per-item spaced-repetition state + the scheduling algorithm
  services/
    data_service.dart             loads the bundled JSON files once at startup
    settings_service.dart         background choice + stats, persisted on-device
    progress_service.dart         spaced-repetition progress + the daily review queue
    audio_service.dart            menu music + click/error sound effects + vibration
    route_observer.dart           lets menu screens resume music when you return to them
  widgets/                        reusable pieces (option buttons, badges, background, rating buttons)
  screens/
    home_screen.dart              mode cards, settings gear, today's review banner
    sentence_mode_screen.dart     browse the 320 sentences, swipe to skip
    kanji_mode_screen.dart        browse the 536 kanji, swipe to skip
    flashcard_screen.dart         swipeable vocab/kanji flashcards, tap to flip
    radical_list_screen.dart      browse/search the 280 radicals
    radical_detail_screen.dart    one radical's meaning, usage, and example kanji
    radical_quiz_screen.dart      MCQ quiz over the 280 radicals
    daily_review_screen.dart      the spaced-repetition review queue
    review_results_screen.dart    Again/Hard/Good/Easy breakdown after a review session
    test_setup_screen.dart        choose content/difficulty/question count
    test_run_screen.dart          the scored quiz itself (now incl. radicals)
    test_results_screen.dart      final score screen
    settings_screen.dart          background picker + sound settings
assets/
  data/*.json                     320 sentences, 536 kanji, 533 vocab words,
                                   280 radicals (precomputed by tested Python
                                   scripts — nothing was re-derived by hand)
  fonts/NotoSansJP-Subset.otf     the same bundled Japanese font from the
                                   desktop app, so kanji render crisp
                                   regardless of what's on your phone
  audio/                          menu music + click/correct/error sound effects
  icon/                           launcher icon source images
```

**Gestures already wired up:** tap to select an answer / flip a flashcard,
swipe left to skip a question, swipe up/down on a flashcard or in Daily
Review to rate it, swipe between flashcards horizontally.

**Background customization** (Settings, gear icon on the home screen):
pick the app's default dark theme, a flat accent color, or any photo from
your gallery — applied behind every screen with an adjustable dim overlay
so text stays readable on top, the same idea as a WhatsApp chat wallpaper.

**Sound & vibration** (Settings): menu music (on/off, volume, default
25%) loops on the home screen, Settings, and Take a Test's setup screen,
and stops the moment you enter any lesson/test/review/flashcard screen —
restarting fresh once you're back. A click sound plays for menu/settings
taps and for lesson/test taps; a wrong answer plays an error sound plus a
short vibration instead.

**No custom launcher icon text is shown in-app anymore** — the Settings
screen's old "About the app icon" info box was removed since it just
cluttered the screen. The icon itself is unchanged: still a light-blue
"文" character, still generated from `assets/icon/`, still swappable any
time by replacing those two PNGs and re-running the icon-generation
command from step 3 above.
