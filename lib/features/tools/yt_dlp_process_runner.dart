import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/command_runner.dart';
import '../download/download_form.dart';
import '../download/download_validation.dart';
import 'yt_dlp_providers.dart';

List<String> downloadArguments(DownloadForm form) => [
  '--ignore-config',
  '--no-playlist',
  '--match-filter',
  '!is_live',
  '--no-overwrites',
  '--no-colors',
  '--encoding',
  'utf-8',
  '--newline',
  '--progress',
  '--no-simulate',
  '--no-quiet',
  '--progress-template',
  'download:YDF_PROGRESS:%(progress)j',
  '--progress-template',
  'postprocess:YDF_POSTPROCESS:%(progress.status)s',
  '--print',
  'after_move:YDF_FILE:%(filepath)s',
  '--paths',
  form.directory.trim(),
  '--output',
  '%(title)s [%(id)s].%(ext)s',
  ...switch (form.format) {
    OutputFormat.automatic => <String>[],
    OutputFormat.mp4 => ['--recode-video', 'mp4'],
    OutputFormat.mkv => ['--remux-video', 'mkv'],
    OutputFormat.mp3 => ['--extract-audio', '--audio-format', 'mp3'],
    OutputFormat.m4a => ['--extract-audio', '--audio-format', 'm4a'],
  },
  '--',
  form.url.trim(),
];

const updateArguments = [
  '--ignore-config',
  '--no-colors',
  '--encoding',
  'utf-8',
  '--update',
];

final ytDlpProcessRunnerProvider = Provider<YtDlpProcessRunner>((ref) {
  final runner = YtDlpProcessRunner(ref.watch(commandRunnerProvider));
  ref.onDispose(runner.dispose);
  return runner;
});

class YtDlpProcessRunner {
  YtDlpProcessRunner(this.commands);

  final CommandRunner commands;
  Process? _process;
  bool _disposed = false;

  Future<void> validateDownload(DownloadForm form) async {
    final error =
        validateVideoUrl(form.url) ?? validateDownloadDirectory(form.directory);
    if (error != null) throw FormatException(error);
    final directory = Directory(form.directory.trim());
    if (!await directory.exists()) {
      throw const FormatException('儲存資料夾不存在，請重新選擇。');
    }
    // Probe write access without overwriting any existing file.
    final probe = await directory.createTemp('.ydf-write-check-');
    await probe.delete();
  }

  Future<int> run(
    String executable,
    List<String> arguments,
    void Function(String) onLine,
  ) async {
    if (_disposed) throw StateError('程序執行服務已關閉。');
    final process = await commands.start(executable, arguments);
    _process = process;
    var exited = false;
    final exitCode = process.exitCode.then((code) {
      exited = true;
      return code;
    });
    const decoder = Utf8Decoder(allowMalformed: true);
    Future<int> read(Stream<List<int>> stream) async {
      await stream
          .transform(decoder)
          .transform(const LineSplitter())
          .forEach(onLine);
      return 0;
    }

    final output = read(process.stdout);
    final errorOutput = read(process.stderr);
    if (_disposed) process.kill();
    try {
      await process.stdin.close();
      final results = await Future.wait([exitCode, output, errorOutput]);
      return results.first;
    } finally {
      if (!exited) process.kill();
      _process = null;
    }
  }

  void dispose() {
    _disposed = true;
    _process?.kill();
  }
}
