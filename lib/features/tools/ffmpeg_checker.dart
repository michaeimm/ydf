import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/command_runner.dart';

class MediaToolStatus {
  const MediaToolStatus({
    required this.name,
    this.executablePath,
    this.version,
    this.error,
  });

  final String name;
  final String? executablePath;
  final String? version;
  final String? error;
  bool get isAvailable => version != null && error == null;
}

class FfmpegChecker {
  const FfmpegChecker({
    required this.commands,
    required this.environment,
    this.timeout = const Duration(seconds: 10),
  });

  final CommandRunner commands;
  final Map<String, String> environment;
  final Duration timeout;

  Future<List<MediaToolStatus>> check() => Future.wait([
    _checkTool('FFmpeg', 'ffmpeg'),
    _checkTool('ffprobe', 'ffprobe'),
  ]);

  Future<String?> _find(String name) async {
    final windows = commands.platform == CommandPlatform.windows;
    final searchPath = environment.entries
        .where(
          (entry) =>
              windows ? entry.key.toUpperCase() == 'PATH' : entry.key == 'PATH',
        )
        .map((entry) => entry.value)
        .firstOrNull;
    for (var entry in (searchPath ?? '').split(windows ? ';' : ':')) {
      if (windows) {
        entry = entry.trim();
        if (entry.length >= 2 && entry.startsWith('"') && entry.endsWith('"')) {
          entry = entry.substring(1, entry.length - 1);
        }
      }
      if (entry.isEmpty) continue;
      final file = File.fromUri(
        Directory(entry).absolute.uri.resolve(windows ? '$name.exe' : name),
      );
      if (await file.exists()) return file.path;
    }
    return null;
  }

  Future<MediaToolStatus> _checkTool(String label, String name) async {
    String? executable;
    try {
      executable = await _find(name);
      if (executable == null) {
        return MediaToolStatus(
          name: label,
          error: '未找到，請將 $name 加入系統 PATH 後重新啟動程式。',
        );
      }
      final version = await _version(executable, name);
      return MediaToolStatus(
        name: label,
        executablePath: executable,
        version: version,
      );
    } on TimeoutException {
      return MediaToolStatus(
        name: label,
        executablePath: executable,
        error: '版本檢查逾時，已停止檢查程序。',
      );
    } catch (error) {
      return MediaToolStatus(
        name: label,
        executablePath: executable,
        error: '無法使用：$error',
      );
    }
  }

  Future<String> _version(String executable, String name) async {
    final process = await commands.start(executable, ['-version']);
    var exited = false;
    final exitCode = process.exitCode.then((code) {
      exited = true;
      return code;
    });
    const decoder = Utf8Decoder(allowMalformed: true);
    final output = process.stdout.transform(decoder).join();
    final errors = process.stderr.transform(decoder).join();
    try {
      await process.stdin.close();
      final result = await Future.wait<Object>([exitCode, output, errors])
          .timeout(timeout);
      if (result[0] != 0) {
        throw StateError(
          '版本檢查失敗（退出碼 ${result[0]}）。${(result[2] as String).trim()}',
        );
      }
      final version = const LineSplitter()
          .convert(result[1] as String)
          .firstWhere(
            (line) => line.startsWith('$name version '),
            orElse: () => '',
          )
          .trim();
      if (version.isEmpty) throw StateError('未回傳有效版本資訊。');
      return version;
    } finally {
      if (!exited) process.kill();
    }
  }
}
