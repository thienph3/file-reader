# Tech Research — Verified APIs (Phase 1)

> Verified 2026-10-18 against pub.dev. All versions are stable and ≥7 days old (dependency quarantine).
> Pin **exact** versions in `pubspec.yaml` (no `^`). Implementation code references this file — do
> not code against unverified APIs.

## Toolchain

- **Flutter** 3.41.9 (stable channel), **Dart** 3.11.5 — verified via `flutter --version`.
- **Android**: no Android SDK in this environment (`flutter doctor`). Phase 1 is verified with
  `flutter test` + `flutter analyze`; APK build / device runs are out-of-band. See `decisions.md`.
- **Min Android SDK**: 24 (aligns with `shared_preferences` SDK 24+ floor). Target/compile SDK 35
  (per `permission_handler` setup guidance).

## State management

**Decision: plain `StatefulWidget` + `setState` for Phase 1** — no state-management package.
Rationale (minimalism ladder): the Phase 1 surface is a single explorer screen plus pushed viewers;
its state is one current directory + per-viewer toggles, all naturally local to a `State`. Riverpod
was considered and **dropped** — adding it (and a `ProviderScope`) with no shared cross-widget state
would be an unused dependency and inert wrapper. Revisit a state-management package only if a later
phase introduces genuinely shared/global state (e.g. a bookmarks store, cross-screen settings). The
plan permits "keep it light"; `setState` is the lightest that works.

## Dependencies (pin exact)

### file_picker — REMOVED from Phase 1 (unused)
- Was pinned at 13.1.0 but never referenced: directory *listing* uses `dart:io` `Directory.list()`,
  and first-run opens the storage root directly, so the system picker was not needed in Phase 1.
  Removed per the minimalism ladder. Re-add (`getDirectoryPath()` → `String?`) if a "choose a browse
  root" flow is wanted later.

### path 1.9.1 — path manipulation (Dart team)
- Import: `import 'package:path/path.dart' as p;`
- Used for `p.extension(name)` (file_type detection, unsupported-modal label). Part of the core Dart
  package ecosystem; stable. Direct dependency so the analyzer doesn't flag an implicit transitive use.

### permission_handler 13.0.2 — storage permission
- Published 44 days ago, publisher baseflow.com.
- Import: `import 'package:permission_handler/permission_handler.dart';`
- Request: `final status = await Permission.storage.request();` → `PermissionStatus`.
  Check with `status.isGranted` / `status.isPermanentlyDenied`.
- On Android, only `request()` can return `permanentlyDenied`; `openAppSettings()` sends the user to
  settings. Android 13+ uses scoped media perms (`READ_MEDIA_*`); declare needed perms in
  `AndroidManifest.xml`. compileSdk 35, `android.useAndroidX=true`.
- Source: https://pub.dev/packages/permission_handler

### shared_preferences 2.5.6 — persist last-viewed directory
- Published 12 days ago, publisher flutter.dev. Android SDK 24+.
- Import: `import 'package:shared_preferences/shared_preferences.dart';`
- **Use the newer async API** (legacy `SharedPreferences.getInstance()` will be deprecated):
  ```dart
  final prefs = SharedPreferencesAsync();
  await prefs.setString('last_dir', path);
  final String? last = await prefs.getString('last_dir');
  ```
- Store only a path string — never file contents.
- Source: https://pub.dev/packages/shared_preferences

### mime 2.1.0 — MIME detection (extension + magic bytes)
- Published 50 days ago, publisher tools.dart.dev (Dart team).
- Import: `import 'package:mime/mime.dart';`
- `String? lookupMimeType(String path, {List<int>? headerBytes})`:
  ```dart
  lookupMimeType('test.html');                       // 'text/html'
  lookupMimeType('x', headerBytes: [0xFF, 0xD8]);    // 'image/jpeg'  (magic-byte fallback)
  ```
- Use extension first; pass `headerBytes` (first ~16 bytes) when the extension is missing/ambiguous.
- Source: https://pub.dev/packages/mime

### csv 8.0.0 — CSV parse
- Published 7 months ago. Dart/Flutter.
- Import: `import 'package:csv/csv.dart';`
- v8 renamed `CsvCodec` → `Csv`. Batch decode (verified against installed source
  `csv-8.0.0/lib/src/csv_codec.dart`):
  ```dart
  final List<List<dynamic>> rows = Csv(dynamicTyping: false).decode(csvString);
  ```
  `Csv({autoDetect: true, dynamicTyping: false, skipEmptyLines: true, ...})`. There is NO
  `CsvToListConverter` in v8 — that was the v6/v7 API. For streaming, `csv.decoder` is a
  `StreamTransformer` emitting one row per event.
- Source: https://pub.dev/packages/csv

### flutter_markdown_plus — DEFERRED to Phase 5 (not a Phase 1 dependency)
- Verified at 1.0.12 (successor to discontinued `flutter_markdown`), but **removed from Phase 1**:
  its transitive `markdown` package stalled `pub get` in this environment, and Markdown rendering is
  a convenience, not core. See `decisions.md` (2026-10-18). In Phase 1, `.md` is detected and opened
  as **plain text** in the text viewer. Re-add when implementing Phase 5.

### xml 7.0.1 — XML parse + pretty-print
- Pinned at 7.0.1 (Dart 3.11.5-compatible; 7.1.0 requires Dart ^3.13.0). Publisher lukas-renggli.ch.
  The API used (`XmlDocument.parse`, `toXmlString(pretty:true)`, `XmlException`) is stable across 7.x.
- Import: `import 'package:xml/xml.dart';`
- Parse + pretty-print:
  ```dart
  final doc = XmlDocument.parse(xmlString);          // throws XmlParserException if malformed
  final pretty = doc.toXmlString(pretty: true, indent: '  ');
  ```
- **XXE safety**: this library does NOT validate against XSD and does NOT resolve external DTD
  entities / fetch external resources — there is no external-entity expansion to exploit. Still cap
  input size/time before parsing to bound DoS. Catch `XmlParserException` → fall back to raw text.
- Source: https://pub.dev/packages/xml

### flutter_widget_from_html_core 0.17.4 — HTML render
- Published 39 days ago, publisher daohoangson.com. Supports 70+ tags.
- Import: `import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';`
- Usage: `HtmlWidget(htmlString, onTapUrl: (url) => true /* no navigation in v1 */)`.
- No script execution, no network by default for our use — render read-only. Do not pass an
  `onTapUrl` that opens arbitrary URLs in v1 (treat links as inert or confirm). Cap input size.
- Source: https://pub.dev/packages/flutter_widget_from_html_core

### JSON — no dependency
- Use `dart:convert`: `const JsonEncoder.withIndent('  ').convert(jsonDecode(src))` for pretty-print.
- `jsonDecode` throws `FormatException` on malformed input → fall back to raw text.

## Not used (and why)
- `flutter_highlight` — last published 5 years ago, unverified uploader. Rejected (stale). JSON/XML
  get pretty-print via stdlib / `xml`; optional lightweight custom colorizing can come later without
  a dependency. (Minimalism ladder: stdlib covers it.)
- `flutter_markdown` — discontinued; replaced by `flutter_markdown_plus`.

## Directory listing (no plugin)
- Use `dart:io` `Directory(path).list()` / `listSync()` → `List<FileSystemEntity>`; `entity is
  Directory` / `entity is File` to split folders vs files. `file_picker` is only for the system
  picker / choosing a root, not for in-app listing.

---

# Tech Research — Phase 2 (Images)

> Verified 2026-10-18 against pub.dev. Pin exact versions. Image decoding/zoom/animation use native
> Flutter — only one new dependency (`exif`).

## No new dependency for zoom / pan / animation
- **Zoom + pan**: `InteractiveViewer` (Flutter SDK widget) — pinch-zoom and pan built in. Wrap the
  image: `InteractiveViewer(minScale: ..., maxScale: ..., child: Image.file(file))`.
- **GIF + animated WebP**: `Image.file(File(path))` animates both natively (Flutter's image codec).
  No animation plugin needed.
- **HEIC**: decoded by the platform codec via `Image` — works on Android API 28+; may fail on older
  or non-Android platforms. Handle with `Image(errorBuilder:)` → graceful error state. EXIF still
  parses from HEIC bytes regardless of whether pixels render.

## exif 3.3.0 — EXIF metadata (the one new dependency)
- Published ~3 years ago; MIT; canonical Dart port of exif-py. SDK `>=2.12.0 <4.0.0` → compatible
  with Dart 3.11.5. Supports TIFF/JPEG/HEIC/PNG/WebP.
- Import: `import 'package:exif/exif.dart';`
- API (verified on pub.dev docs + readme):
  ```dart
  final Map<String, IfdTag> data = await readExifFromBytes(bytes);
  // IfdTag has a `.printable` String (human-readable value).
  // Keys 'JPEGThumbnail' / 'TIFFThumbnail' hold raw thumbnail blobs — drop them from a panel.
  ```
- Only decodes metadata; no code execution. Wrap calls to never throw and cap the byte input.
- Source: https://pub.dev/packages/exif · https://pub.dev/documentation/exif/latest/

## Not used (and why)
- `photo_view` (0.15.0, ~2.5 yr old) — rejected; `InteractiveViewer` (stdlib) covers zoom/pan.
- Any GIF plugin — rejected; native `Image` animates GIF/WebP.
- A bundled HEIC decoder — rejected for now; rely on the platform codec + graceful fallback.

---

# Tech Research — Phase 3 (Documents)

> Verified 2026-10-18 against pub.dev + installed source. Pinned exact. Decision rationale + the xml
> downgrade are in `delivery/2026-10-18-flutter-documents-phase3/decisions.md`.

## Approach: PDF renders; Office is extract-to-content; .pptx deferred
No local-only, high-fidelity Office renderer exists for Flutter. So:
- **PDF** → real native rendering (`pdfx`).
- **.docx** → text extraction (`docx_to_text`) in a read-only text view.
- **.xlsx** → cell extraction (`spreadsheet_decoder`) into a table.
- **.pptx** → detected as a document but routes to the Unsupported modal (no viable renderer).

## pdfx 2.11.0 — PDF rendering
- Published 59 days ago, verified publisher serge.software. SDK `>=3.3.0 <4.0.0` → OK on Dart 3.11.5.
  Renders via the platform PDF engine (Android `PdfRenderer` API 21+).
- Import: `import 'package:pdfx/pdfx.dart';`
- API (verified on pub.dev):
  ```dart
  final controller = PdfControllerPinch(document: PdfDocument.openFile(path));
  PdfViewPinch(                       // pinch-zoom without quality loss
    controller: controller,
    onDocumentError: (err) { ... },   // graceful failure
    builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
      options: const DefaultBuilderOptions(),
      documentLoaderBuilder: (_) => ...,
      errorBuilder: (err) => ...,
    ),
  );
  // Page nav via controller; onPageChanged / onDocumentLoaded callbacks.
  ```
- Dispose the controller in `State.dispose`.
- Source: https://pub.dev/packages/pdfx

## docx_to_text 1.0.1 — .docx text extraction
- ~3 years old, MIT. Depends on `archive` + `xml` (`^6.2.2` — one reason for the xml downgrade).
- API: `String docxToText(List<int> bytes)` — returns plain text (no layout). Verified in source
  `docx_to_text-1.0.1/lib/src/docx_to_text_src.dart`.
- Wrap to never throw on malformed input; cap byte read. Text shown in the existing text viewer path.

## spreadsheet_decoder 2.3.0 — .xlsx cell extraction
- ~2 years old. Depends on `archive ^3.6.1` + `xml ^6.5.0` (the other reason for the downgrade).
- API (verified in `spreadsheet_decoder-2.3.0/lib/src/spreadsheet.dart`):
  ```dart
  final d = SpreadsheetDecoder.decodeBytes(bytes);   // factory, sync
  final Map<String, SpreadsheetTable> tables = d.tables;
  for (final t in tables.values) {
    final List<List> rows = t.rows;   // cells as dynamic
  }
  ```
- Wrap to never throw; cap byte read; render first sheet's rows in a table (reuse CSV-style table).

## xml downgraded 7.0.1 -> 6.6.1
- Required: both Office readers cap xml `<7.0.0`. Our XML viewer uses only `XmlDocument.parse`,
  `toXmlString(pretty:true)`, `XmlException` — stable across 6.x. Regression-verified: the Phase 1
  content_format + structured-viewer tests pass on 6.6.1. See phase3/decisions.md.

## Not used (and why)
- `pdfrx` — latest requires Dart ^3.13.0 (we are on 3.11.5). Rejected on SDK incompatibility.
- `syncfusion_flutter_pdfviewer` — commercial license + latest release <7 days old. Rejected.
- `excel` — needs xml `<7.0.0` AND pulls a heavier dep set than `spreadsheet_decoder`; the lighter
  reader covers read-only cell extraction. Rejected in favour of `spreadsheet_decoder`.

---

# Tech Research — Phase 4 (Media & Archives)

> Verified 2026-10-18 against pub.dev + installed source. Pinned exact. Media *playback* uses the
> platform codec and is device-dependent (verified on-device); the player/browser *structure* is the
> logic under test.

## just_audio 0.10.6 — audio playback
- sdk ^3.6.0, flutter >=3.27.0 → OK on Dart 3.11.5 / Flutter 3.41.9. 111 days old.
- Import: `import 'package:just_audio/just_audio.dart';`
- API (stable; verified in source): `final player = AudioPlayer();
  await player.setFilePath(path);` then `player.play()` / `player.pause()`. Streams:
  `player.positionStream` (`Stream<Duration>`), `player.durationStream` (`Stream<Duration?>`),
  `player.playerStateStream`. `await player.dispose()` on teardown.
- Codec support is the platform's: mp3/m4a/wav play on Android; `.ogg` (Vorbis) is supported on
  Android but device-dependent. Show a graceful error if a source fails to load.
- Source: https://pub.dev/packages/just_audio

## video_player 2.10.1 — video playback
- Pinned at 2.10.1 (sdk ^3.7.0, flutter >=3.29.0 → compatible). The latest 2.14.x needs Dart ^3.12.0
  / Flutter >=3.44.0 — INCOMPATIBLE with our toolchain, so pin 2.10.1. 341 days old.
- Import: `import 'package:video_player/video_player.dart';`
- API (verified in source): `final c = VideoPlayerController.file(File(path));
  await c.initialize();` then `VideoPlayer(c)` widget + `c.play()/pause()`; `c.value` holds
  `isInitialized`, `duration`, `position`, `hasError`. `c.dispose()` on teardown.
- Codec is ExoPlayer on Android: mp4/webm supported; `.mkv` (Matroska) is usually supported but
  device-dependent. Use `controller.value.hasError` / init failure → graceful error state.
- Source: https://pub.dev/packages/video_player

## archive 3.6.1 — zip browse + inner preview
- Promoted from dev-dependency to a regular dependency (the zip browser uses it in `lib/`).
- Import: `import 'package:archive/archive.dart';`
- API (verified in source): `final Archive a = ZipDecoder().decodeBytes(bytes);` — `Archive` is
  `Iterable<ArchiveFile>` with `.files`. Each `ArchiveFile`: `name` (path within zip), `size`,
  `isFile`, `isSymbolicLink`, `content` (bytes, lazily inflated).
- **Security (Threat Model)**: list entries without inflating; inflate a single inner file's
  `content` only on user tap AND only when within a size cap (zip-bomb bound). Sanitize `name` and
  **skip** absolute paths, `..` traversal, and symlinks. Never write extracted bytes to disk — inner
  preview is in-memory, routed back through the existing viewers (text/image/etc.) via the registry.
- Source: https://pub.dev/packages/archive

## Capability notes (honest)
- Audio/video *rendering* is device-dependent (platform codec). ogg/mkv especially may fail on some
  devices → graceful error state, never a crash. Verified on-device.
- The zip browser reuses `detectFileType` + `ViewerRegistry` to preview inner files, so a `.zip`
  containing a `.txt`/`.json`/image opens it with the same viewer the explorer would use.

---

# Tech Research — Phase 5 (Reading & Long Tail)

> Verified 2026-10-18 against installed source. Markdown stays deferred (the `markdown` transitive of
> `flutter_markdown_plus` still won't `pub get`). `.cbr` (RAR) deferred — no maintainable Dart unrar.
> New deps are cached for offline resolve: `epubx`, `flutter_svg` (+ `vector_graphics*`).

## Zero-dependency long tail — detection → existing text viewer
Config/markup and source-code extensions are just plain text; map them to the existing text family:
- Config/markup → `FileType.plainText`: `yaml yml toml ini properties env conf cfg`
- Source code → `FileType.plainText`: `dart py js ts jsx tsx java kt c h cpp cc hpp cs go rs rb php
  swift sh bash sql css scss`
- `.rtf` → a tiny pure `rtfToText` helper (strip `\control` words + groups) → text viewer. No dep.
These add no packages — only `_extensionMap` entries (+ a `rtf_to_text.dart` helper).

## epubx 4.0.0 — EPUB parsing (the reading headline)
- sdk `>=2.12.0 <4.0.0` → OK on Dart 3.11.5. Deps `archive ^3.1.6` + `xml ^6.0.1` → compatible with
  our `archive 3.6.1` + `xml 6.6.1`. 1205 days old but the canonical Dart EPUB parser; MIT.
- Import: `import 'package:epubx/epubx.dart';`
- API (verified in source):
  ```dart
  final EpubBook book = await EpubReader.readBook(bytes);   // bytes: List<int>
  book.Title;                 // String?
  book.Chapters;              // List<EpubChapter>?  (each: Title, HtmlContent, SubChapters)
  // EpubChapter.HtmlContent is an HTML string per chapter.
  ```
- Render chapter HTML with the existing `flutter_widget_from_html_core` (Phase 1 dep) — no new HTML
  renderer. Wrap parsing to never throw; cap the byte read (zip-based, bomb-bound).

## flutter_svg 2.3.0 — SVG vector images
- sdk ^3.9.0 (OK on 3.11.5), flutter >=3.35.0 (OK on 3.41.9). 162 days. Publisher dnfield.
- Import: `import 'package:flutter_svg/flutter_svg.dart';`
- API: `SvgPicture.file(File(path))` and `SvgPicture.string(svgSource)` (verified in source
  `svg.dart`). Render inside `InteractiveViewer` for zoom/pan (reuse the image-viewer pattern).
- SVG is XML — parsed by flutter_svg's own vector pipeline; show an error placeholder on parse
  failure (its loaders expose a `placeholderBuilder`).

## .cbz (comic/manga) — reuse the zip archive browser + image inner-preview
- A `.cbz` is a ZIP of images. Detect `cbz` → route to the Phase 4 `ArchiveBrowser`, and ADD
  **image inner-preview** there (currently text-family only): inflate a tapped image entry
  (size-capped, in-memory) and show it with `Image.memory`. This also upgrades Phase 4's zip image
  handling. Entries already sort alphabetically = page order. No new dependency (uses `archive`).

## Pinned for offline (cached 2026-10-18)
epubx 4.0.0 · flutter_svg 2.3.0 · vector_graphics 1.2.3 · vector_graphics_codec 1.1.13 ·
vector_graphics_compiler 1.3.2.

---

# Tech Research — Phase 6 (PPTX content)

> No new dependencies. `.pptx` is OpenXML (ZIP of XML), read with the existing `archive` + `xml`.
> Technique verified locally (no network) before coding.

## PPTX per-slide text (archive + xml)
- Slides live at `ppt/slides/slideN.xml`. Enumerate entries matching `^ppt/slides/slide\d+\.xml$`
  and **sort by the numeric N** (lexical sort would put slide10 before slide2).
- Per slide: `XmlDocument.parse(content).findAllElements('a:t')` → each `.innerText` is a text run;
  keep non-empty, in document order (best-effort reading order).
- `xml` 6.6.1 does not resolve external DTD entities (same XXE basis as the JSON/XML viewer). Cap the
  byte read; wrap parsing to never throw (malformed/not-pptx → empty).
- No fidelity rendering: this is slide *text*, consistent with `.docx`/`.xlsx` extraction.

## .cbr — still deferred
RAR candidates (`unrar`, `flutter_rar`, `rar`) are native-`ffi` (need an NDK; not headless-verifiable)
and `koni_rar` is a pre-1.0 single-author package; new-package fetches also stalled `pub get` here.
Deferred, not attempted. `.cbz` covers the common comic case.
