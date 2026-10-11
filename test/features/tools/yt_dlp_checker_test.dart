import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ydf/core/command_runner.dart';
import 'package:ydf/features/tools/yt_dlp_checker.dart';

void main() {
  late String dartExecutable;
  late Directory root;
  late Directory application;
  late Directory pathDirectory;

  setUpAll(() async {
    final configFile = File('.dart_tool/package_config.json').absolute;
    final config = jsonDecode(await configFile.readAsString()) as Map;
    final flutter = (config['packages'] as List).cast<Map>().singleWhere(
      (package) => package['name'] == 'flutter',
    );
    final flutterDirectory = Directory.fromUri(
      configFile.uri.resolve(flutter['rootUri'] as String),
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
    root = await Directory.systemTemp.createTemp('ydf tools 中文 ');
    application = await Directory.fromUri(root.uri.resolve('app/')).create();
    pathDirectory = await Directory.fromUri(root.uri.resolve('path/')).create();
  });

  tearDown(() async => root.delete(recursive: true));

  Future<String> placeTool(
    Directory directory, {
    String name = 'yt-dlp.exe',
  }) async {
    final file = File.fromUri(directory.uri.resolve(name));
    await file.writeAsString(
      'Test placeholder; launched through the probe runner.',
    );
    return file.path;
  }

  YtDlpChecker checker(
    _ProbeCommandRunner commands, {
    Map<String, String>? environment,
    Duration timeout = const Duration(seconds: 10),
  }) => YtDlpChecker(
    commands: commands,
    applicationDirectory: application,
    environment: environment ?? {'PATH': pathDirectory.path},
    timeout: timeout,
  );

  test(
    'application tool wins over PATH and reports absolute path and version',
    () async {
      final local = await placeTool(application);
      await placeTool(pathDirectory);
      final commands = _ProbeCommandRunner(dartExecutable);
      final installation = await checker(commands).check();

      expect(installation.executablePath, local);
      expect(installation.version, '2026.10.11');
      expect(commands.executables, [local]);
      expect(commands.arguments, ['--ignore-config', '--version']);
    },
  );

  test('Windows PATH supports mixed-case key, quotes, spaces and entry order', () async {
    final first = await placeTool(pathDirectory);
    final secondDirectory = await Directory.fromUri(root.uri.resolve('second/'))
        .create();
    await placeTool(secondDirectory);
    final commands = _ProbeCommandRunner(dartExecutable);
    final installation = await checker(
      commands,
      environment: {
        'Path':
            ';${root.path}/missing;"${pathDirectory.path}";${secondDirectory.path};',
      },
    ).check();

    expect(installation.executablePath, first);
  });

  test('missing tool does not launch a process', () async {
    final commands = _ProbeCommandRunner(dartExecutable);
    await expectLater(
      checker(commands, environment: {}).check(),
      throwsA(
        isA<YtDlpCheckException>().having(
          (error) => error.message,
          'message',
          contains('找不到 yt-dlp'),
        ),
      ),
    );
    expect(commands.executables, isEmpty);
  });

  test(
    'unusable local tool reports stderr without falling back to PATH',
    () async {
      final local = await placeTool(application);
      await placeTool(pathDirectory);
      final commands = _ProbeCommandRunner(dartExecutable, mode: 'failure');
      await expectLater(
        checker(commands).check(),
        throwsA(
          isA<YtDlpCheckException>()
              .having((error) => error.executablePath, 'path', local)
              .having((error) => error.message, 'message', contains('退出碼 2'))
              .having((error) => error.message, 'stderr', contains('版本檢查測試錯誤')),
        ),
      );
      expect(commands.executables, [local]);
    },
  );

  test('launch failure includes selected tool path', () async {
    final local = await placeTool(application);
    final commands = _ProbeCommandRunner(dartExecutable, mode: 'launch-error');
    await expectLater(
      checker(commands).check(),
      throwsA(
        isA<YtDlpCheckException>()
            .having((error) => error.executablePath, 'path', local)
            .having((error) => error.message, 'message', contains('無法啟動')),
      ),
    );
  });

  test('successful exit without a version is rejected', () async {
    await placeTool(application);
    final commands = _ProbeCommandRunner(dartExecutable, mode: 'empty');
    await expectLater(
      checker(commands).check(),
      throwsA(
        isA<YtDlpCheckException>().having(
          (error) => error.message,
          'message',
          contains('未回傳版本'),
        ),
      ),
    );
  });

  test('timeout kills the actual child process', () async {
    await placeTool(application);
    final commands = _ProbeCommandRunner(dartExecutable, mode: 'timeout');
    await expectLater(
      checker(commands, timeout: const Duration(milliseconds: 200)).check(),
      throwsA(
        isA<YtDlpCheckException>().having(
          (error) => error.message,
          'message',
          contains('逾時'),
        ),
      ),
    );
    expect(
      await commands.process!.exitCode.timeout(const Duration(seconds: 5)),
      isNot(0),
    );
  });

  for (final (platform, name) in [
    (CommandPlatform.macos, 'yt-dlp_macos'),
    (CommandPlatform.linux, 'yt-dlp_linux'),
  ]) {
    test('recognizes $platform local release filename', () async {
      final local = await placeTool(application, name: name);
      final commands = _ProbeCommandRunner(dartExecutable, platform: platform);
      expect((await checker(commands).check()).executablePath, local);
    });
  }
}

/// Uses real child processes while keeping discovery independent of installed tools.
class _ProbeCommandRunner implements CommandRunner {
  _ProbeCommandRunner(
    this.dartExecutable, {
    this.mode = 'success',
    this.platform = CommandPlatform.windows,
  });

  final String dartExecutable;
  final String mode;
  @override
  final CommandPlatform platform;
  final executables = <String>[];
  List<String>? arguments;
  Process? process;

  @override
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    executables.add(executable);
    this.arguments = arguments;
    if (mode == 'launch-error') {
      throw ProcessException(executable, arguments, 'Test launch failure');
    }
    return process = await CommandRunner().start(dartExecutable, [
      File('test/fixtures/yt_dlp_probe.dart').absolute.path,
      mode,
    ]);
  }

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Encoding stdoutEncoding = utf8,
    Encoding stderrEncoding = utf8,
  }) => throw UnimplementedError('The version check uses a streaming process.');
}
