import 'package:file_reader/core/file_ref.dart';
import 'package:file_reader/core/file_type.dart';
import 'package:file_reader/explorer/directory_lister.dart';
import 'package:file_reader/explorer/explorer_sort.dart';
import 'package:file_reader/explorer/view_mode.dart';
import 'package:flutter_test/flutter_test.dart';

Entry _dir(String name, {DateTime? mod}) =>
    Entry.directory(name, '/x/$name', modified: mod);

Entry _file(String name, FileType type, {int? size, DateTime? mod}) =>
    Entry.file(
      FileRef(path: '/x/$name', name: name, type: type, size: size),
      modified: mod,
    );

List<String> _names(List<Entry> e) => e.map((x) => x.name).toList();

void main() {
  group('applyView — visibility', () {
    test('hides dotfiles unless showHidden', () {
      final list = <Entry>[_file('.secret', FileType.plainText), _file('a.txt', FileType.plainText)];
      expect(
        _names(applyView(list,
            field: SortField.name,
            direction: SortDirection.ascending,
            foldersFirst: true,
            showHidden: false)),
        <String>['a.txt'],
      );
      expect(
        _names(applyView(list,
            field: SortField.name,
            direction: SortDirection.ascending,
            foldersFirst: true,
            showHidden: true)),
        <String>['.secret', 'a.txt'],
      );
    });
  });

  group('applyView — folders first', () {
    test('groups folders before files when enabled', () {
      final list = <Entry>[_file('b.txt', FileType.plainText), _dir('Apps'), _file('a.txt', FileType.plainText)];
      expect(
        _names(applyView(list,
            field: SortField.name,
            direction: SortDirection.ascending,
            foldersFirst: true,
            showHidden: false)),
        <String>['Apps', 'a.txt', 'b.txt'],
      );
    });

    test('interleaves by name when disabled', () {
      final list = <Entry>[_file('b.txt', FileType.plainText), _dir('Apps'), _file('a.txt', FileType.plainText)];
      expect(
        _names(applyView(list,
            field: SortField.name,
            direction: SortDirection.ascending,
            foldersFirst: false,
            showHidden: false)),
        <String>['a.txt', 'Apps', 'b.txt'],
      );
    });
  });

  group('applyView — sort fields & direction', () {
    test('by size ascending / descending', () {
      final list = <Entry>[
        _file('big.bin', FileType.unsupported, size: 900),
        _file('small.txt', FileType.plainText, size: 10),
        _file('mid.txt', FileType.plainText, size: 100),
      ];
      expect(
        _names(applyView(list,
            field: SortField.size,
            direction: SortDirection.ascending,
            foldersFirst: false,
            showHidden: false)),
        <String>['small.txt', 'mid.txt', 'big.bin'],
      );
      expect(
        _names(applyView(list,
            field: SortField.size,
            direction: SortDirection.descending,
            foldersFirst: false,
            showHidden: false)),
        <String>['big.bin', 'mid.txt', 'small.txt'],
      );
    });

    test('by date modified (newest first when descending)', () {
      final list = <Entry>[
        _file('old.txt', FileType.plainText, mod: DateTime(2020)),
        _file('new.txt', FileType.plainText, mod: DateTime(2026)),
      ];
      expect(
        _names(applyView(list,
            field: SortField.date,
            direction: SortDirection.descending,
            foldersFirst: false,
            showHidden: false)),
        <String>['new.txt', 'old.txt'],
      );
    });

    test('by type groups extensions, dirs first regardless', () {
      final list = <Entry>[
        _file('z.txt', FileType.plainText),
        _file('a.json', FileType.json),
        _dir('Folder'),
      ];
      final out = _names(applyView(list,
          field: SortField.type,
          direction: SortDirection.ascending,
          foldersFirst: true,
          showHidden: false));
      expect(out.first, 'Folder'); // dir groups first
      expect(out.contains('a.json') && out.contains('z.txt'), isTrue);
    });

    test('does not mutate the input list', () {
      final list = <Entry>[_file('b', FileType.plainText), _file('a', FileType.plainText)];
      final before = _names(list);
      applyView(list,
          field: SortField.name,
          direction: SortDirection.ascending,
          foldersFirst: false,
          showHidden: false);
      expect(_names(list), before);
    });
  });

  group('ExplorerPrefs', () {
    test('defaults: list, name asc, folders-first on, hidden off', () {
      const p = ExplorerPrefs();
      expect(p.viewMode, ViewMode.list);
      expect(p.sortField, SortField.name);
      expect(p.sortDirection, SortDirection.ascending);
      expect(p.foldersFirst, isTrue);
      expect(p.showHidden, isFalse);
    });

    test('copyWith overrides only the given fields', () {
      const p = ExplorerPrefs();
      final q = p.copyWith(viewMode: ViewMode.grid, showHidden: true);
      expect(q.viewMode, ViewMode.grid);
      expect(q.showHidden, isTrue);
      expect(q.sortField, SortField.name); // unchanged
      expect(q.foldersFirst, isTrue); // unchanged
    });
  });
}
