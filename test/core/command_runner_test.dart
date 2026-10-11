import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ydf/core/command_runner.dart';

void main() {
  final runner = CommandRunner();
  late String dartExecutable;
  late String probe;

  setUpAll(() async {
    // Flutter's test runtime cannot resolve package URIs via dart:isolate.
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
    probe = File('test/fixtures/command_probe.dart').absolute.path;
  });

  test('detects desktop platforms and rejects unsupported systems', () {
    expect(
      CommandPlatform.fromOperatingSystem('windows'),
      CommandPlatform.windows,
    );
    expect(CommandPlatform.fromOperatingSystem('macos'), CommandPlatform.macos);
    expect(CommandPlatform.fromOperatingSystem('linux'), CommandPlatform.linux);
    expect(
      () => CommandPlatform.fromOperatingSystem('android'),
      throwsUnsupportedError,
    );
    expect(
      runner.platform,
      CommandPlatform.fromOperatingSystem(Platform.operatingSystem),
    );
  });

  test(
    'preserves arguments, cwd, environment, output and nonzero exit',
    () async {
      final directory = await Directory.systemTemp.createTemp('ydf 中文 space ');
      addTearDown(() => directory.delete(recursive: true));
      const arguments = ['中文 空白', 'a&b|c', '"quoted"', '', '%PATH%', r'$HOME'];
      final result = await runner.run(
        dartExecutable,
        [probe, ...arguments],
        workingDirectory: directory.path,
        environment: {'YDF_COMMAND_TEST': 'passed'},
      );
      final output =
          jsonDecode(result.stdout as String) as Map<String, dynamic>;
      expect(output['arguments'], arguments);
      expect(output['workingDirectory'], directory.path);
      expect(output['environment'], 'passed');
      expect(result.stderr, contains('測試 stderr'));
      expect(result.exitCode, 7);
    },
  );

  test('start exposes both streams and exit status', () async {
    final process = await runner.start(dartExecutable, [probe, 'stream 中文']);
    final output = process.stdout.transform(utf8.decoder).join();
    final error = process.stderr.transform(utf8.decoder).join();
    await process.stdin.close();
    expect(await process.exitCode, 7);
    expect(jsonDecode(await output)['arguments'], ['stream 中文']);
    expect(await error, contains('測試 stderr'));
  });

  test(
    'launch failures remain ProcessException for both entry points',
    () async {
      final missing = File('test/fixtures/missing_program.exe').absolute.path;
      await expectLater(
        runner.run(missing, []),
        throwsA(isA<ProcessException>()),
      );
      await expectLater(
        runner.start(missing, []),
        throwsA(isA<ProcessException>()),
      );
    },
  );

  test('rejects empty executable names', () async {
    await expectLater(runner.run(' ', []), throwsArgumentError);
    await expectLater(runner.start('', []), throwsArgumentError);
  });

  test('rejects Windows batch scripts for both entry points', () async {
    for (final executable in ['tool.bat', 'TOOL.CMD']) {
      await expectLater(runner.run(executable, []), throwsArgumentError);
      await expectLater(runner.start(executable, []), throwsArgumentError);
    }
  }, skip: !Platform.isWindows);
}
