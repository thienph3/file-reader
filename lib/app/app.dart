import 'package:flutter/material.dart';

import '../explorer/app_bootstrap.dart';
import '../viewers/registry.dart';

/// The root application widget. The explorer is the home surface; viewers are
/// pushed on top and popped back to it (see plan's Navigation & flow).
class FileReaderApp extends StatelessWidget {
  const FileReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'File Reader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFEB6C36)),
        useMaterial3: true,
      ),
      home: AppBootstrap(registry: buildPhase1Registry()),
    );
  }
}
