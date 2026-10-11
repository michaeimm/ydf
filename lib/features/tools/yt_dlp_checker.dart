import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/command_runner.dart';

class YtDlpInstallation {
  const YtDlpInstallation({
    required this.executablePath,
    required this.version,
  });

  final String executablePath;
  final String version;
}

class YtDlpCheckException implements Exception {
  const YtDlpCheckException(this.message, {this.executablePath});

  final String message;
  final String? executablePath;

  @override
  String toString() => message;
}

class YtDlpChecker {
  YtDlpChecker({
    required this.commands,
    required this.applicationDirectory,
    required this.environment,
    this.timeout = const Duration(seconds: 10),
  });

  final CommandRunner commands;
  final Directory applicationDirectory;
  final Map<String, String> environment;
  final Duration timeout;

  List<String> get _executableNames => switch (commands.platform) {
    CommandPlatform.windows => ['yt-dlp.exe'],
    CommandPlatform.macos => ['yt-dlp', 'yt-dlp_macos'],
    CommandPlatform.linux => ['yt-dlp', 'yt-dlp_linux'],
  };

  Future<String?> _findIn(Directory directory) async {
    for (final name in _executableNames) {
      final file = File.fromUri(directory.absolute.uri.resolve(name));
      if (await file.exists()) return file.path;
    }
    return null;
  }

  Future<String?> _findExecutable() async {
    final local = await _findIn(applicationDirectory);
    if (local != null) return local;

    final isWindows = commands.platform == CommandPlatform.windows;
    String? searchPath;
    for (final entry in environment.entries) {
      if (isWindows ? entry.key.toUpperCase() == 'PATH' : entry.key == 'PATH') {
        searchPath = entry.value;
        break;
      }
    }
    for (final entry in (searchPath ?? '').split(isWindows ? ';' : ':')) {
      var path = entry;
      if (isWindows) {
        path = path.trim();
        if (path.startsWith('"') && path.endsWith('"') && path.length >= 2) {
          path = path.substring(1, path.length - 1);
        }
      }
      // An empty PATH entry must not accidentally search the working directory.
      if (path.isEmpty) continue;
      final executable = await _findIn(Directory(path));
      if (executable != null) return executable;
    }
    return null;
  }

  Future<YtDlpInstallation> check() async {
    final executable = await _findExecutable();
    if (executable == null) {
      throw const YtDlpCheckException(
        '找不到 yt-dlp。請放入應用程式目錄後重新檢查，或加入系統 PATH 後重新啟動程式。',
      );
    }

    try {
      return await _checkVersion(executable);
    } on ProcessException catch (error) {
      throw YtDlpCheckException(
        '無法啟動 yt-dlp：${error.message}',
        executablePath: executable,
      );
    } on TimeoutException {
      throw YtDlpCheckException(
        'yt-dlp 版本檢查逾時，已停止檢查程序。',
        executablePath: executable,
      );
    }
  }

  Future<YtDlpInstallation> _checkVersion(String executable) async {
    final process = await commands.start(executable, [
      '--ignore-config',
      '--version',
    ]);
    var exited = false;
    final exitCode = process.exitCode.then((code) {
      exited = true;
      return code;
    });
    const decoder = Utf8Decoder(allowMalformed: true);
    final output = process.stdout.transform(decoder).join();
    final errorOutput = process.stderr.transform(decoder).join();

    try {
      await process.stdin.close();
      final result = await Future.wait<Object>([exitCode, output, errorOutput])
          .timeout(timeout);
      final code = result[0] as int;
      final version = (result[1] as String).trim();
      final error = (result[2] as String).trim();
      if (code != 0) {
        throw YtDlpCheckException(
          'yt-dlp 版本檢查失敗（退出碼 $code）。${error.isEmpty ? '' : '\n$error'}',
          executablePath: executable,
        );
      }
      if (version.isEmpty) {
        throw YtDlpCheckException(
          'yt-dlp 未回傳版本資訊。',
          executablePath: executable,
        );
      }
      return YtDlpInstallation(executablePath: executable, version: version);
    } finally {
      if (!exited) process.kill();
    }
  }
}
