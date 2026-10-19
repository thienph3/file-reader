import 'package:file_reader/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildTheme', () {
    test('uses Inter and Material 3', () {
      final t = buildTheme(brightness: Brightness.light);
      expect(t.textTheme.bodyMedium?.fontFamily, 'Inter');
      expect(t.useMaterial3, isTrue);
    });

    test('falls back to the seed scheme when no dynamic scheme', () {
      final light = buildTheme(brightness: Brightness.light);
      final dark = buildTheme(brightness: Brightness.dark);
      expect(light.colorScheme.brightness, Brightness.light);
      expect(dark.colorScheme.brightness, Brightness.dark);
    });

    test('prefers a provided dynamic scheme', () {
      final dynamicScheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF0066FF),
        brightness: Brightness.light,
      );
      final t = buildTheme(
        brightness: Brightness.light,
        dynamicScheme: dynamicScheme,
      );
      // The harmonized dynamic scheme (blue) should differ from the tangerine
      // seed's primary — i.e. the dynamic palette was actually used.
      final seedOnly = buildTheme(brightness: Brightness.light);
      expect(t.colorScheme.primary, isNot(seedOnly.colorScheme.primary));
    });
  });
}
