import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import '../explorer/app_bootstrap.dart';
import '../viewers/registry.dart';
import 'theme.dart';

/// The root application widget. The explorer is the home surface; viewers are
/// pushed on top and popped back to it (see plan's Navigation & flow).
///
/// Uses the platform Material You palette when available (Android 12+) via
/// [DynamicColorBuilder], falling back to the brand seed; honours the system
/// light/dark setting.
class FileReaderApp extends StatelessWidget {
  const FileReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          title: 'File Reader',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.system,
          theme: buildTheme(
            brightness: Brightness.light,
            dynamicScheme: lightDynamic,
          ),
          darkTheme: buildTheme(
            brightness: Brightness.dark,
            dynamicScheme: darkDynamic,
          ),
          home: AppBootstrap(registry: buildPhase1Registry()),
        );
      },
    );
  }
}
