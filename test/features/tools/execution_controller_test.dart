import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ydf/core/command_runner.dart';
import 'package:ydf/features/download/download_form.dart';
import 'package:ydf/features/download/download_validation.dart';
import 'package:ydf/features/tools/execution_controller.dart';
import 'package:ydf/features/tools/yt_dlp_checker.dart';
import 'package:ydf/features/tools/yt_dlp_process_runner.dart';
import 'package:ydf/features/tools/yt_dlp_providers.dart';

import '../../support/controlled_runner.dart';

const tool = YtDlpInstallation(
  executablePath: r'C:\tools\yt-dlp.exe',
  version: 'old',
);
const request = DownloadForm(
  url: 'https://www.youtube.com/watch?v=video&list=ignored',
  directory: r'C:\中文 下載',
);

void main() {
  test('invalid UTF-8 in URL components returns a validation error', () {
    for (final url in [
      'https://youtu.be/%FF',
      'https://www.youtube.com/watch?v=%FF',
    ]) {
      expect(validateVideoUrl(url), '請輸入有效的 YouTube 影片網址。', reason: url);
    }
  });

  test('validates single video URLs and rejects other hosts or playlists', () {
    for (final url in [
      request.url,
      'https://youtu.be/video',
      'https://m.youtube.com/shorts/video',
      'https://youtube.com/live/video',
    ]) {
      expect(validateVideoUrl(url), isNull);
    }
    for (final url in [
      '',
      'https://youtube.com/playlist?list=test',
      'https://youtube.com/@channel',
      'https://youtube.com.evil/watch?v=id',
      'file:///video',
      'https://evil@youtube.com/watch?v=id',
    ]) {
      expect(validateVideoUrl(url), isNotNull);
    }
    expect(validateDownloadDirectory('relative/folder'), isNotNull);
    expect(validateDownloadDirectory(Directory.systemTemp.path), isNull);
  });

  test('download arguments preserve paths/URL, disable playlist and select formats', () {
    for (final format in OutputFormat.values) {
      final arguments = downloadArguments(request.copyWith(format: format));
      expect(
        arguments,
        containsAll(['--ignore-config', '--no-playlist', '--no-overwrites']),
      );
      expect(arguments[arguments.indexOf('--paths') + 1], request.directory);
      expect(arguments.sublist(arguments.length - 2), ['--', request.url]);
      final formatArguments = switch (format) {
        OutputFormat.automatic => <String>[],
        OutputFormat.mp4 => ['--recode-video', 'mp4'],
        OutputFormat.mkv => ['--remux-video', 'mkv'],
        OutputFormat.mp3 => ['--extract-audio', '--audio-format', 'mp3'],
        OutputFormat.m4a => ['--extract-audio', '--audio-format', 'm4a'],
      };
      if (formatArguments.isNotEmpty) {
        expect(arguments, containsAllInOrder(formatArguments));
      } else {
        expect(arguments, isNot(contains('--recode-video')));
        expect(arguments, isNot(contains('--extract-audio')));
      }
    }
  });

  test(
    'checks existing writable directory without leaving probe files',
    () async {
      final directory = await Directory.systemTemp.createTemp('ydf validate ');
      addTearDown(() => directory.delete(recursive: true));
      final runner = YtDlpProcessRunner(CommandRunner());
      await runner.validateDownload(
        request.copyWith(directory: directory.path),
      );
      expect(await directory.list().toList(), isEmpty);
      await expectLater(
        runner.validateDownload(
          request.copyWith(directory: '${directory.path}/missing'),
        ),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        runner.validateDownload(
          request.copyWith(
            url: 'https://example.com/video',
            directory: directory.path,
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test(
    'download and update are mutually exclusive; 100% is not completion',
    () async {
      final runner = ControlledRunner();
      final container = ProviderContainer.test(
        overrides: [
          ytDlpCheckProvider.overrideWith((ref) async => tool),
          ytDlpProcessRunnerProvider.overrideWithValue(runner),
        ],
      );
      await container.read(ytDlpCheckProvider.future);
      final controller = container.read(executionProvider.notifier);
      final download = controller.download(request);
      await runner.started.future;
      expect(runner.executable, tool.executablePath);
      await controller.update();
      await controller.download(request);
      expect(runner.calls, 1);
      runner.emit('YDF_PROGRESS:{"downloaded_bytes":50,"total_bytes":100}');
      expect(container.read(executionProvider).progress, 0.5);
      runner.emit('YDF_PROGRESS:{"downloaded_bytes":100,"total_bytes":100}');
      expect(container.read(executionProvider).isBusy, isTrue);
      runner.emit('YDF_POSTPROCESS:started');
      expect(
        container.read(executionProvider).phase,
        ExecutionPhase.processing,
      );
      runner.emit('YDF_FILE:C:\\下載\\video.mp4');
      runner.result.complete(0);
      await download;
      expect(container.read(executionProvider).phase, ExecutionPhase.completed);
      expect(container.read(executionProvider).logs.last, contains('儲存檔案：'));
    },
  );

  test(
    'stderr/failed postprocessing remains visible and logs are bounded',
    () async {
      final runner = ControlledRunner();
      final container = ProviderContainer.test(
        overrides: [
          ytDlpCheckProvider.overrideWith((ref) async => tool),
          ytDlpProcessRunnerProvider.overrideWithValue(runner),
        ],
      );
      await container.read(ytDlpCheckProvider.future);
      final download = container
          .read(executionProvider.notifier)
          .download(request);
      await runner.started.future;
      for (var i = 0; i < 250; i++) {
        runner.emit('line $i');
      }
      runner.emit('ERROR: ffmpeg not found');
      runner.result.complete(1);
      await download;
      final state = container.read(executionProvider);
      expect(state.phase, ExecutionPhase.failed);
      expect(state.logs.join('\n'), contains('ffmpeg not found'));
      expect(state.logs.length, 200);
      expect(state.isBusy, isFalse);
    },
  );

  test(
    'skipped downloads without an output file cannot report success',
    () async {
      final runner = ControlledRunner();
      final container = ProviderContainer.test(
        overrides: [
          ytDlpCheckProvider.overrideWith((ref) async => tool),
          ytDlpProcessRunnerProvider.overrideWithValue(runner),
        ],
      );
      await container.read(ytDlpCheckProvider.future);
      final download = container
          .read(executionProvider.notifier)
          .download(request);
      await runner.started.future;
      runner.emit('[download] video does not pass filter');
      runner.result.complete(0);
      await download;
      expect(container.read(executionProvider).phase, ExecutionPhase.failed);
      expect(container.read(executionProvider).logs.last, contains('未回報輸出檔案'));
    },
  );

  test(
    'update targets the selected executable then refreshes its version',
    () async {
      final runner = ControlledRunner();
      var checks = 0;
      final container = ProviderContainer.test(
        overrides: [
          ytDlpCheckProvider.overrideWith((ref) async {
            checks++;
            return checks == 1
                ? tool
                : const YtDlpInstallation(
                    executablePath: r'C:\tools\yt-dlp.exe',
                    version: 'new',
                  );
          }),
          ytDlpProcessRunnerProvider.overrideWithValue(runner),
        ],
      );
      await container.read(ytDlpCheckProvider.future);
      final update = container.read(executionProvider.notifier).update();
      await runner.started.future;
      expect(runner.executable, tool.executablePath);
      expect(runner.arguments, updateArguments);
      expect(runner.arguments, isNot(contains('--update-to')));
      runner.emit('Updated yt-dlp');
      runner.result.complete(0);
      await update;
      expect(checks, 2);
      expect(container.read(ytDlpCheckProvider).asData!.value.version, 'new');
      expect(container.read(executionProvider).message, 'yt-dlp 更新完成（new）');
    },
  );

  test(
    'unsupported self-update reports failure and rechecks the tool',
    () async {
      final runner = ControlledRunner();
      var checks = 0;
      final container = ProviderContainer.test(
        overrides: [
          ytDlpCheckProvider.overrideWith((ref) async {
            checks++;
            return tool;
          }),
          ytDlpProcessRunnerProvider.overrideWithValue(runner),
        ],
      );
      await container.read(ytDlpCheckProvider.future);
      final update = container.read(executionProvider.notifier).update();
      await runner.started.future;
      runner.emit('ERROR: use pip to update this installation');
      runner.result.complete(100);
      await update;
      await container.read(ytDlpCheckProvider.future);
      expect(checks, 2);
      expect(container.read(executionProvider).phase, ExecutionPhase.failed);
      expect(
        container.read(executionProvider).logs.join('\n'),
        contains('use pip'),
      );
    },
  );
}
