import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:ydf/core/command_runner.dart';
import 'package:ydf/features/tools/ffmpeg_checker.dart';

void main() {
  late String dartExecutable;
  late Directory directory;

  setUpAll(() async {
    final file = File('.dart_tool/package_config.json').absolute;
    final config = jsonDecode(await file.readAsString()) as Map;
    final flutter = (config['packages'] as List).cast<Map>().singleWhere(
      (package) => package['name'] == 'flutter',
    );
    final flutterDirectory = Directory.fromUri(
      file.uri.resolve(flutter['rootUri'] as String),
    );
    final sdk = Directory(await flutterDirectory.resolveSymbolicLinks())
        .parent
        .parent
        .uri;
    dartExecutable = sdk
        .resolve(
          'bin/cache/dart-sdk/bin/${Platform.isWindows ? 'dart.exe' : 'dart'}',
        )
        .toFilePath();
  });
  setUp(() async {
    // Relative POSIX PATH fixtures must not include a Windows drive colon.
    directory = await Directory.current.createTemp('ydf media tools 中文 ');
  });
  tearDown(() => directory.delete(recursive: true));

  Future<void> place(String name) async {
    await File.fromUri(directory.uri.resolve(name)).writeAsString('fixture');
  }

  FfmpegChecker checker(
    _ProbeRunner runner, {
    Duration timeout = const Duration(seconds: 10),
  }) => FfmpegChecker(
    commands: runner,
    environment: runner.platform == CommandPlatform.windows
        ? {'Path': ';"${directory.path}";'}
        : {'PATH': path.relative(directory.path).replaceAll(r'\', '/')},
    timeout: timeout,
  );

  for (final platform in CommandPlatform.values) {
    test('checks both versions on $platform using controlled PATH', () async {
      final suffix = platform == CommandPlatform.windows ? '.exe' : '';
      await place('ffmpeg$suffix');
      await place('ffprobe$suffix');
      final runner = _ProbeRunner(dartExecutable, platform: platform);
      final result = await checker(runner).check();
      expect(result.map((tool) => tool.isAvailable), [true, true]);
      expect(result.map((tool) => tool.version), [
        'ffmpeg version test-build',
        'ffprobe version test-build',
      ]);
      expect(result.map((tool) => tool.executablePath), [
        File.fromUri(directory.uri.resolve('ffmpeg$suffix')).path,
        File.fromUri(directory.uri.resolve('ffprobe$suffix')).path,
      ]);
      expect(runner.arguments, everyElement(['-version']));
    });
  }

  test('missing ffprobe does not hide usable FFmpeg', () async {
    await place('ffmpeg.exe');
    final runner = _ProbeRunner(dartExecutable);
    final result = await checker(runner).check();
    expect(result.first.isAvailable, isTrue);
    expect(result.last.error, contains('未找到'));
    expect(runner.arguments, hasLength(1));
  });

  for (final mode in ['failure', 'empty', 'launch-error', 'timeout']) {
    test('$mode is reported without failing the other tool', () async {
      await place('ffmpeg.exe');
      await place('ffprobe.exe');
      final runner = _ProbeRunner(dartExecutable, mode: mode);
      final result = await checker(
        runner,
        timeout: const Duration(seconds: 1),
      ).check();
      expect(result.first.isAvailable, isFalse);
      expect(result.first.executablePath, isNotNull);
      expect(result.last.isAvailable, isTrue);
      expect(
        result.first.error,
        contains(switch (mode) {
          'failure' => 'test version failure',
          'empty' => '未回傳有效版本',
          'timeout' => '逾時',
          _ => 'test launch failure',
        }),
      );
      if (mode == 'timeout') {
        expect(
          await runner.ffmpeg!.exitCode.timeout(const Duration(seconds: 5)),
          isNot(0),
        );
      }
    });
  }
}

class _ProbeRunner implements CommandRunner {
  _ProbeRunner(
    this.dartExecutable, {
    this.platform = CommandPlatform.windows,
    this.mode = 'success',
  });
  final String dartExecutable;
  final String mode;
  @override
  final CommandPlatform platform;
  final arguments = <List<String>>[];
  Process? ffmpeg;

  @override
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    this.arguments.add(arguments);
    final name = path.basenameWithoutExtension(executable);
    final selectedMode = name == 'ffmpeg' ? mode : 'success';
    if (selectedMode == 'launch-error') {
      throw ProcessException(executable, arguments, 'test launch failure');
    }
    final process = await CommandRunner().start(dartExecutable, [
      File('test/fixtures/media_tool_probe.dart').absolute.path,
      name,
      selectedMode,
    ]);
    if (name == 'ffmpeg') ffmpeg = process;
    return process;
  }

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Encoding stdoutEncoding = utf8,
    Encoding stderrEncoding = utf8,
  }) => throw UnimplementedError();
}
