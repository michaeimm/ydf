import 'dart:io';

import '../../core/command_runner.dart';

/// Locates Deno without making it a prerequisite for using yt-dlp.
class DenoChecker {
  const DenoChecker({required this.platform, required this.environment});

  final CommandPlatform platform;
  final Map<String, String> environment;

  Future<String?> check({String? ytDlpExecutable}) async {
    final isWindows = platform == CommandPlatform.windows;
    final name = isWindows ? 'deno.exe' : 'deno';
    final directories = <Directory>[];
    if (isWindows && ytDlpExecutable != null) {
      directories.add(File(ytDlpExecutable).parent);
    }
    final searchPath = environment.entries
        .where(
          (entry) => isWindows
              ? entry.key.toUpperCase() == 'PATH'
              : entry.key == 'PATH',
        )
        .map((entry) => entry.value)
        .firstOrNull;
    for (var entry in (searchPath ?? '').split(isWindows ? ';' : ':')) {
      if (isWindows) {
        entry = entry.trim();
        if (entry.length >= 2 && entry.startsWith('"') && entry.endsWith('"')) {
          entry = entry.substring(1, entry.length - 1);
        }
      }
      if (entry.isNotEmpty) directories.add(Directory(entry));
    }
    for (final directory in directories) {
      final file = File.fromUri(directory.absolute.uri.resolve(name));
      if (await file.exists()) return file.path;
    }
    return null;
  }
}
