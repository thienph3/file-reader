import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// Shows the "Unsupported file" modal (a bottom sheet) for [fileName].
///
/// Per the plan's Navigation & flow: unsupported files do NOT push a viewer
/// route — this sheet names the file + extension, offers a single dismiss, and
/// leaves the user in the explorer at the current directory.
Future<void> showUnsupportedModal(BuildContext context, String fileName) {
  final ext = p.extension(fileName);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text("Can't open this file",
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                ),
                if (ext.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Theme.of(context).colorScheme.primary),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(ext,
                        style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '$fileName — this format isn\'t supported yet. '
              'Support for more formats arrives in later phases.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      );
    },
  );
}
