import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

/// Brand seed used when the platform provides no dynamic (Material You) palette.
const Color kSeedColor = Color(0xFFEB6C36); // atomic tangerine

/// Builds the app's [ThemeData] for a given [brightness], preferring a
/// platform dynamic [ColorScheme] (Material You, Android 12+) and falling back
/// to a seed-generated scheme. Applies the bundled Inter typography and a few
/// refined component themes. Pure given its inputs — easy to unit-test.
ThemeData buildTheme({
  required Brightness brightness,
  ColorScheme? dynamicScheme,
}) {
  final ColorScheme scheme = (dynamicScheme ??
          ColorScheme.fromSeed(seedColor: kSeedColor, brightness: brightness))
      .harmonized();

  final base = ThemeData(
    colorScheme: scheme,
    brightness: scheme.brightness,
    useMaterial3: true,
    fontFamily: 'Inter',
  );

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 2,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      iconColor: scheme.onSurfaceVariant,
      minVerticalPadding: 10,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.5),
      thickness: 0.6,
      space: 0.6,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      showDragHandle: true,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
