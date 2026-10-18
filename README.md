# File Reader

An Android-first Flutter app that is a **file explorer first** — browse the files and folders on
your device, then open any file to read it in a built-in viewer and tap back to return to the
explorer. Readable formats are added in **phases**, starting with the most popular file extensions
and expanding outward. Each phase is shippable on its own — the app is useful after Phase 1 and gets
richer with every phase.

## Why

People accumulate files of every kind on their phones — text notes, photos, PDFs, spreadsheets,
the odd archive. A single, fast, no-nonsense explorer that lets you browse everything in one place
and open the common formats first (and the long tail later) beats juggling a dozen single-purpose
apps.

## How it works

The explorer is the home screen. On first launch it asks for storage access (if needed) and shows
your files from the storage root; on later launches it reopens the folder you were last viewing.
Tapping a folder jumps into it. Tapping a file whose format is supported pushes a viewer for it — the
system back button (or the viewer's back arrow) returns you to the explorer right where you left off.
Tapping a file whose format isn't supported yet shows a brief "unsupported" dialog and leaves you in
the explorer. Opening a file from another app ("open with") jumps straight to the viewer, and backing
out drops you into the explorer — so the explorer is always one tap away.

## Scope

- **Platform:** Android first. The codebase stays platform-neutral where practical so iOS/desktop
  can follow later, but no effort is spent on them now.
- **Read-only:** This is a *viewer*. Editing, conversion, and sharing are out of scope for the
  initial roadmap (sharing may be revisited later).
- **Local files:** Open files from device storage and via the system file picker / "open with"
  intent. Cloud providers are out of scope for now.

## Phased Roadmap

Extensions are ordered by real-world popularity, so the earliest phases cover the formats most
users open most often. A phase ships only when its formats open reliably and the file browser +
viewer shell around them works.

### Phase 1 — Foundation + Plain Text & Structured Text
The explorer home surface (browse files/folders), permissions, the "open with" intent, and the
explorer→viewer→back navigation, plus the simplest and most common readable formats.

| Category | Extensions |
|---|---|
| Plain text | `.txt`, `.log`, `.md` |
| Structured text | `.json`, `.xml`, `.csv`, `.html` |

Deliverables: the file/folder **explorer** as the home screen (directory navigation, storage
permission flow, `VIEW`/`SEND` intent handling), open-file → push-viewer → back-to-explorer
navigation, a text viewer with monospace/wrap toggle (`.md` opens here as plain text — rich Markdown
rendering lands in Phase 5), syntax-aware rendering for JSON/XML, and a tabular view for CSV.

### Phase 2 — Images
| Category | Extensions |
|---|---|
| Raster images | `.jpg`, `.jpeg`, `.png`, `.gif`, `.webp`, `.bmp`, `.heic` |

Deliverables: image viewer with pinch-zoom/pan, animated GIF playback, EXIF metadata panel.

### Phase 3 — Documents
| Category | Extensions |
|---|---|
| Portable docs | `.pdf` |
| Office | `.docx`, `.xlsx`, `.pptx` |

Deliverables: PDF viewer (page navigation, pinch-zoom) via a native renderer. Office formats are
read-only **content extraction** (no local-only fidelity renderer exists): `.docx` → text, `.xlsx` →
first-sheet table, `.pptx` → per-slide text (added in Phase 6 — not rendered slides).

### Phase 4 — Media & Archives
| Category | Extensions |
|---|---|
| Audio | `.mp3`, `.m4a`, `.wav`, `.ogg` |
| Video | `.mp4`, `.mkv`, `.webm` |
| Archives | `.zip` (browse/extract-preview) |

Deliverables: audio player (play/pause, seek), video player (play/pause, scrubber), and a zip archive
browser that lists entries and previews supported (text-family) inner files in memory. `.ogg`/`.mkv`
playback is device-codec-dependent.

### Phase 5 — Reading & Long Tail
Reading formats and the popular long tail: **EPUB** e-book reader (`.epub`, chapter navigation),
**comic/manga** browsing (`.cbz` — zip of images with in-app page preview), **SVG** vector images
(`.svg`), and the config/source-code files users open constantly (`.yaml .toml .ini`, `.dart .py .js
.go .rs .sql .css`, …) plus `.rtf` — all opened read-only. Rich Markdown rendering and `.cbr` (RAR)
are **deferred** (dependency availability — see `.../phase5/decisions.md`); `.md` stays plain text.

## Tech Stack

- **Flutter** (stable channel) + **Dart**
- **State management:** plain `StatefulWidget` + `setState` for Phase 1 (no state-management package
  — the surface is a single explorer screen plus pushed viewers). Revisited per phase; rationale in
  `docs/tech.md`.
- **Key plugins** (exact versions pinned during per-phase research in `docs/tech.md`):
  - File access / picker, storage permissions
  - Markdown rendering, syntax highlighting
  - Image/EXIF, PDF rendering, media playback, archive handling
- **Min Android SDK / target SDK:** pinned in Phase 1 research

> Dependency versions are deliberately **not** guessed here. Each phase's research task verifies the
> current, stable, 7-day-aged versions and records them in `docs/tech.md` before any code is written.

## Getting Started

The Flutter project is scaffolded and Phase 1 is implemented.

```bash
# Prerequisites: Flutter SDK (stable 3.41.x), and — to build/run on-device — the Android SDK
flutter --version
flutter pub get
flutter test       # run unit/widget tests (41 tests)
flutter analyze    # static analysis (expected: no issues)
flutter run        # launch on an attached Android device/emulator
```

> **Note:** tests and analysis run without the Android SDK. Building an APK (`flutter build apk`)
> and the "open with" intent flow require the Android SDK / a device. See
> `.kiro/delivery/2026-10-18-flutter-file-reader/decisions.md` for the two Phase 1 scope notes
> (Markdown rendering deferred to Phase 5; "open with" Dart-side URI routing is a device follow-up —
> the manifest filter is in place).

See [`docs/building.md`](docs/building.md) for the full build & test guide (commands, headless vs.
on-device verification, and troubleshooting).

## Project Structure

```
lib/
  main.dart
  app/            # app shell (MaterialApp, theme)
  explorer/       # home surface: browse, permissions, navigation, last-dir, unsupported modal
  viewers/
    text/         # Phase 1: text/log, JSON/XML, CSV, HTML (+ Phase 5: config/source, .rtf)
    image/        # Phase 2: image viewer (zoom/pan, GIF, EXIF) (+ Phase 5: .svg)
    document/     # Phase 3: PDF viewer + .docx/.xlsx content extraction
    media/        # Phase 4: audio + video players
    archive/      # Phase 4: zip browser (+ Phase 5: .cbz image page preview)
    reading/      # Phase 5: EPUB reader (chapter nav)
  core/           # file-type detection, FileRef, viewer registry
test/             # unit + widget tests mirroring lib/
docs/             # tech.md (verified, pinned APIs)
design/           # screens.html — Phase 1 screen mockups
```

## Delivery Plan

Full plan, design decisions, and the parallelized task breakdown live under
`.kiro/delivery/2026-10-18-flutter-file-reader/`:

- `plan.md` — context, decision, constraints, design, risks
- `tasks.md` — phased, parallelized task groups

## Status

**Phase 1 — complete.** The explorer (first-run storage root / last-viewed folder on return, folder
navigation, supported-file → viewer, unsupported-file → modal) and four viewers (text/log, JSON/XML,
CSV, HTML) are implemented and reviewed.

**Phase 2 — complete.** Image viewer for `.jpg .jpeg .png .gif .webp .bmp .heic` — pinch-zoom/pan
(`InteractiveViewer`), native animated GIF/WebP playback, and a toggleable EXIF metadata panel
(`exif` package).

**Phase 3 — complete.** Documents: a real **PDF viewer** (`pdfx` — native rendering, page
navigation, pinch-zoom, graceful error state). Office formats are **read-only content extraction**,
not fidelity rendering: `.docx` → extracted text, `.xlsx` → first-sheet table, `.pptx` → per-slide
text (added in Phase 6). No on-device slide/office *renderer* exists, so these read content, not layout.

**Phase 4 — complete.** Media & archives: an **audio player** (`just_audio` — play/pause, seek bar)
for `.mp3 .m4a .wav .ogg`; a **video player** (`video_player` — play/pause, scrubber) for
`.mp4 .mkv .webm`; and a **zip archive browser** (`archive`) that lists entries and previews
text-family inner files in memory.

**Phase 5 — complete.** Reading & long tail: an **EPUB reader** (`epubx` — chapter navigation,
HTML rendered via `flutter_widget_from_html_core`), **comic/manga** browsing (`.cbz` — the zip
browser now previews image pages in memory), **SVG** vector images (`flutter_svg`, pinch-zoom), the
config/source-code long tail (`.yaml .toml .ini`, `.dart .py .js .go .rs .sql .css`, … → text
viewer), and `.rtf` (extracted to text).

**Phase 6 — complete.** `.pptx` now opens as a **per-slide text outline** (each slide's text,
extracted from the OpenXML via the existing `archive` + `xml` — no new dependency, no slide
rendering). `flutter analyze` is clean and 109 unit/widget tests pass.

Deliberately deferred / scoped: **rich Markdown rendering** and **`.cbr`** (RAR) remain deferred for
dependency availability (`.md` stays plain text; no maintainable pub-get-able unrar — see
`.../phase5/decisions.md` and `.../phase6/decisions.md`); the Dart-side "open with" URI routing → a
device follow-up (the Android `VIEW` intent filter is declared).
Device-dependent and verified on-device rather than headless: HEIC decoding + image pixel rendering
(platform codec, Android API 28+), PDF page rendering (`pdfx`), audio/video playback (platform codec
— `.ogg`/`.mkv` especially vary by device), and SVG/EPUB-HTML layout (renderer). The EPUB happy-path
parse is device-verified (its safety contract is unit-tested). Office viewers (`.docx`/`.xlsx`/`.pptx`)
read content, not layout. Zip/CBZ inner-preview is scoped to text + images in memory (no disk writes);
other inner types show the Unsupported modal. Pins of note: `xml` 6.6.1 (Office readers need <7.x) and
`video_player` 2.10.1 (toolchain) — see the respective phase `decisions.md`.
