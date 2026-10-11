import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ydf/core/command_runner.dart';
import 'package:ydf/features/tools/deno_checker.dart';
import 'package:ydf/features/tools/yt_dlp_checker.dart';
import 'package:ydf/features/tools/yt_dlp_providers.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('ydf deno 中文 ');
  });
  tearDown(() => root.delete(recursive: true));

  Future<String> place(String folder, String name) async {
    final directory = await Directory.fromUri(root.uri.resolve('$folder/'))
        .create();
    return (await File.fromUri(directory.uri.resolve(name))
            .writeAsString('fixture'))
        .path;
  }

  test('finds Windows Deno beside the selected yt-dlp outside PATH', () async {
    final deno = await place('tool', 'deno.exe');
    final ytDlp = File.fromUri(root.uri.resolve('tool/yt-dlp.exe')).path;
    const checker = DenoChecker(
      platform: CommandPlatform.windows,
      environment: {},
    );
    expect(await checker.check(ytDlpExecutable: ytDlp), deno);
  });

  test('finds Windows Deno in quoted mixed-case PATH', () async {
    final deno = await place('path', 'deno.exe');
    final checker = DenoChecker(
      platform: CommandPlatform.windows,
      environment: {'Path': ';"${File(deno).parent.path}";'},
    );
    expect(await checker.check(), deno);
  });

  test('missing Deno returns null without launching any process', () async {
    final checker = DenoChecker(
      platform: CommandPlatform.windows,
      environment: {'PATH': root.path},
    );
    expect(await checker.check(), isNull);
  });

  test(
    'provider checks PATH then checks beside yt-dlp when it becomes ready',
    () async {
      final deno = await place('tool', 'deno.exe');
      final ytDlp = Completer<YtDlpInstallation>();
      final container = ProviderContainer.test(
        overrides: [
          ytDlpCheckProvider.overrideWith((ref) => ytDlp.future),
          denoCheckerProvider.overrideWithValue(
            const DenoChecker(
              platform: CommandPlatform.windows,
              environment: {},
            ),
          ),
        ],
      );
      final subscription = container.listen(denoCheckProvider, (_, _) {});
      addTearDown(subscription.close);
      expect(await container.read(denoCheckProvider.future), isNull);
      ytDlp.complete(
        YtDlpInstallation(
          executablePath: File.fromUri(root.uri.resolve('tool/yt-dlp.exe'))
              .path,
          version: 'test',
        ),
      );
      await container.read(ytDlpCheckProvider.future);
      await container.pump();
      expect(await container.read(denoCheckProvider.future), deno);
    },
  );

  test('provider checks Deno even when yt-dlp is missing', () async {
    final deno = await place('path', 'deno.exe');
    final container = ProviderContainer.test(
      overrides: [
        ytDlpCheckProvider.overrideWith(
          (ref) async => throw const YtDlpCheckException('missing'),
        ),
        denoCheckerProvider.overrideWithValue(
          DenoChecker(
            platform: CommandPlatform.windows,
            environment: {'PATH': File(deno).parent.path},
          ),
        ),
      ],
    );
    final subscription = container.listen(denoCheckProvider, (_, _) {});
    addTearDown(subscription.close);
    await expectLater(
      container.read(ytDlpCheckProvider.future),
      throwsA(isA<YtDlpCheckException>()),
    );
    await container.pump();
    expect(await container.read(denoCheckProvider.future), deno);
  });

  for (final platform in [CommandPlatform.macos, CommandPlatform.linux]) {
    test('finds $platform Deno in PATH', () async {
      final deno = await place('path', 'deno');
      final checker = DenoChecker(
        platform: platform,
        environment: {'PATH': '${root.path}/missing:${File(deno).parent.path}'},
      );
      expect(await checker.check(), deno);
    });
  }
}
