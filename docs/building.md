# Building & Testing

How to set up, run the test suite, analyse, and build the **File Reader** app (Android-first Flutter).

## Prerequisites

| Tool | Version | Needed for |
|---|---|---|
| **Flutter SDK** | stable **3.41.x** (built against 3.41.9) | everything |
| **Dart** | 3.11.x (bundled with Flutter) | everything |
| **Android SDK** + a device/emulator | API 24+ (target/compile 35) | building an APK, running on-device |
| Git | any | cloning |

> **You do NOT need the Android SDK to run the tests or static analysis.** The test suite and
> `flutter analyze` run headless on the Dart VM. The Android SDK is only required to build an APK or
> run the app on a device/emulator.

Check your toolchain:

```bash
flutter --version      # expect: Flutter 3.41.x • channel stable
flutter doctor         # Android toolchain row only matters for on-device builds
```

## First-time setup

Dependencies are **pinned to exact versions** and committed in `pubspec.lock`. Just fetch them:

```bash
flutter pub get
```

> If `pub get` is slow or stalls on a fresh machine, it is fetching packages from pub.dev for the
> first time. Once the pub cache is warm, `flutter pub get --offline` resolves instantly.

## Run the tests

```bash
flutter test                       # whole suite — expect: All tests passed! (109 tests)
flutter test test/core/            # just the detection / registry tests
flutter test test/viewers/         # just the viewer + content-extraction tests
flutter test path/to/one_test.dart # a single file
flutter test --name "pattern"      # tests whose description matches
```

What the suite covers (headless): file-type detection, the viewer registry, explorer navigation
logic, and every viewer's content/parse logic (JSON/XML/CSV/HTML formatting, EXIF, Office + PPTX
extraction, zip-entry safety, rtf/epub parsing). No device required.

## Static analysis

```bash
flutter analyze                    # expect: No issues found!
dart format --output=none --set-exit-if-changed .   # optional: check formatting
```

Both are part of the definition of done — a change should keep `analyze` clean and the suite green.

## Build & run on Android (needs the Android SDK)

```bash
flutter devices                    # list attached devices / running emulators
flutter run                        # debug run on the selected device
flutter build apk --debug          # debuggable APK
flutter build apk --release        # release APK (build/app/outputs/flutter-apk/)
flutter build appbundle --release  # Play Store bundle
```

The app requests scoped storage permission on first launch, then lists the storage root (or the
last-viewed folder on subsequent launches).

## What is NOT verifiable headless

Some behaviour depends on the Android platform codec / renderer and is verified **on-device**, not by
the test suite (the logic around it *is* tested — detection, parsing, error states):

- Image pixel rendering and **HEIC** decoding (platform codec, API 28+)
- **PDF** page rendering (`pdfx` uses the platform PDF engine)
- **Audio/video** playback — `.ogg` and `.mkv` especially vary by device codec
- **SVG** rasterisation and **EPUB** chapter HTML layout (renderer)
- The **"open with"** (`VIEW` intent) end-to-end flow — the Android manifest filter is declared; the
  Dart-side URI routing is a device follow-up

## Troubleshooting

| Symptom | Fix |
|---|---|
| `pub get` version-solve failure | The lockfile is committed — run plain `flutter pub get`; don't bump pins by hand. Some deps are pinned below latest for toolchain compatibility (e.g. `xml 6.6.1`, `video_player 2.10.1`) — see the per-phase `decisions.md` under `.kiro/delivery/`. |
| `flutter analyze` flags a package import | A dependency used in `lib/` must be a direct dependency (not transitive). Add it to `pubspec.yaml` with an exact pin. |
| Tests pass individually but fail together | Usually a stale assertion in another file (e.g. a newly supported extension). Run the full suite and fix the stale test. |
| APK build fails: "Unable to locate Android SDK" | Install the Android SDK / Android Studio, or `flutter config --android-sdk <path>`. Not needed for `flutter test`. |

## Project layout (where things live)

```
lib/        app shell, explorer, viewers (text/image/document/media/archive/reading), core
test/       unit + widget tests mirroring lib/
docs/       tech.md (verified, pinned APIs), building.md (this file)
.kiro/delivery/<phase>/   per-phase plan.md, tasks.md, decisions.md, review.md, security-review.md
```
