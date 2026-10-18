import 'package:file_reader/core/file_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('detectFileType — by extension', () {
    test('plain text families', () {
      expect(detectFileType('notes.txt'), FileType.plainText);
      expect(detectFileType('server.log'), FileType.plainText);
    });

    test('markdown keeps its family (routed to text viewer in Phase 1)', () {
      expect(detectFileType('README.md'), FileType.markdown);
    });

    test('structured text families', () {
      expect(detectFileType('config.json'), FileType.json);
      expect(detectFileType('feed.xml'), FileType.xml);
      expect(detectFileType('budget.csv'), FileType.csv);
      expect(detectFileType('index.html'), FileType.html);
      expect(detectFileType('page.htm'), FileType.html);
    });

    test('is case-insensitive on the extension', () {
      expect(detectFileType('NOTES.TXT'), FileType.plainText);
      expect(detectFileType('Data.JSON'), FileType.json);
    });

    test('uses only the final path segment extension', () {
      expect(detectFileType('/storage/emulated/0/Docs/a.b.csv'), FileType.csv);
    });

    test('image family (Phase 2)', () {
      for (final name in <String>[
        'photo.jpg',
        'photo.jpeg',
        'icon.png',
        'anim.gif',
        'pic.webp',
        'old.bmp',
        'shot.heic',
      ]) {
        expect(detectFileType(name), FileType.image, reason: name);
      }
    });

    test('image extensions are case-insensitive', () {
      expect(detectFileType('PHOTO.JPG'), FileType.image);
      expect(detectFileType('Shot.HEIC'), FileType.image);
    });

    test('document family (Phase 3)', () {
      expect(detectFileType('report.pdf'), FileType.pdf);
      expect(detectFileType('letter.docx'), FileType.docx);
      expect(detectFileType('budget.xlsx'), FileType.xlsx);
      expect(detectFileType('deck.pptx'), FileType.pptx);
    });

    test('document extensions are case-insensitive', () {
      expect(detectFileType('REPORT.PDF'), FileType.pdf);
      expect(detectFileType('Deck.PPTX'), FileType.pptx);
    });

    test('media + archive families (Phase 4)', () {
      for (final n in <String>['song.mp3', 'clip.m4a', 'rec.wav', 'tune.ogg']) {
        expect(detectFileType(n), FileType.audio, reason: n);
      }
      for (final n in <String>['movie.mp4', 'show.mkv', 'clip.webm']) {
        expect(detectFileType(n), FileType.video, reason: n);
      }
      expect(detectFileType('bundle.zip'), FileType.archive);
    });

    test('media + archive extensions are case-insensitive', () {
      expect(detectFileType('SONG.MP3'), FileType.audio);
      expect(detectFileType('Movie.MP4'), FileType.video);
      expect(detectFileType('Bundle.ZIP'), FileType.archive);
    });

    test('reading + long-tail families (Phase 5)', () {
      expect(detectFileType('book.epub'), FileType.epub);
      expect(detectFileType('logo.svg'), FileType.svg);
      expect(detectFileType('manga.cbz'), FileType.archive);
      expect(detectFileType('notes.rtf'), FileType.rtf);
    });

    test('config + source-code extensions open as plain text (Phase 5)', () {
      for (final n in <String>[
        'config.yaml',
        'app.yml',
        'Cargo.toml',
        'settings.ini',
        'main.dart',
        'script.py',
        'index.js',
        'server.go',
        'lib.rs',
        'query.sql',
        'style.css',
      ]) {
        expect(detectFileType(n), FileType.plainText, reason: n);
      }
    });

    test('Phase 5 extensions are case-insensitive', () {
      expect(detectFileType('BOOK.EPUB'), FileType.epub);
      expect(detectFileType('Logo.SVG'), FileType.svg);
      expect(detectFileType('Manga.CBZ'), FileType.archive);
      expect(detectFileType('Main.DART'), FileType.plainText);
    });
  });

  group('detectFileType — fallback', () {
    test('unknown extension with no helpful MIME is unsupported', () {
      expect(detectFileType('data.bin'), FileType.unsupported);
      expect(detectFileType('firmware.iso'), FileType.unsupported);
    });

    test('resolves via MIME when the extension is unknown but mime maps it', () {
      // `.text` is not in our _extensionMap, but package:mime maps it to
      // text/plain, which our MIME fallback resolves to FileType.plainText.
      expect(detectFileType('plain.text'), FileType.plainText);
    });

    test('no magic number for HTML text -> unsupported (mime has none)', () {
      // package:mime registers magic bytes for binary formats (JPEG/PNG/...),
      // not for HTML text. A no-extension HTML file is therefore unsupported;
      // this is expected and the explorer shows the modal.
      final html = '<!DOCTYPE html>'.codeUnits;
      expect(detectFileType('mysteryfile', headerBytes: html),
          FileType.unsupported);
    });

    test('extension wins over conflicting magic bytes', () {
      final jpegMagic = <int>[0xFF, 0xD8, 0xFF];
      // .csv extension should still classify as csv even if bytes look binary.
      expect(
        detectFileType('data.csv', headerBytes: jpegMagic),
        FileType.csv,
      );
    });

    test('empty / dotfile names are unsupported, never throw', () {
      expect(detectFileType(''), FileType.unsupported);
      expect(detectFileType('.gitignore'), FileType.unsupported);
    });
  });
}
