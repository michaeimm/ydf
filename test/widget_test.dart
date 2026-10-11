import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ydf/features/download/download_form.dart';
import 'package:ydf/features/download/download_page.dart';
import 'package:ydf/features/tools/ffmpeg_checker.dart';
import 'package:ydf/features/tools/yt_dlp_checker.dart';
import 'package:ydf/features/tools/yt_dlp_providers.dart';
import 'package:ydf/features/tools/yt_dlp_process_runner.dart';
import 'package:ydf/main.dart';

import 'support/controlled_runner.dart';

const installation = YtDlpInstallation(
  executablePath: r'C:\tools\yt-dlp.exe',
  version: '2026.10.11',
);

const readyMediaTools = [
  MediaToolStatus(name: 'FFmpeg', version: 'ffmpeg version test'),
  MediaToolStatus(name: 'ffprobe', version: 'ffprobe version test'),
];

Widget testApp() => ProviderScope(
  overrides: [
    ffmpegCheckProvider.overrideWith((ref) async => readyMediaTools),
    denoCheckProvider.overrideWith((ref) async => null),
    ytDlpCheckProvider.overrideWith((ref) async => installation),
  ],
  child: const MyApp(),
);

void main() {
  testWidgets('media checks show versions, warn on missing tools and refresh', (
    tester,
  ) async {
    var checks = 0;
    final pending = Completer<List<MediaToolStatus>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ytDlpCheckProvider.overrideWith((ref) async => installation),
          denoCheckProvider.overrideWith((ref) async => null),
          ffmpegCheckProvider.overrideWith((ref) {
            checks++;
            return checks == 1 ? pending.future : Future.value(readyMediaTools);
          }),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pump();
    expect(find.text('FFmpeg／ffprobe：檢查中…'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    pending.complete(const [
      MediaToolStatus(name: 'FFmpeg', version: 'ffmpeg version test'),
      MediaToolStatus(name: 'ffprobe', error: '未找到'),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('FFmpeg：已就緒（ffmpeg version test）'), findsOneWidget);
    expect(find.text('ffprobe：未找到'), findsOneWidget);
    expect(find.textContaining('影音合併、音訊擷取或轉檔可能失敗'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.system_update_alt),
          )
          .onPressed,
      isNotNull,
    );
    await tester.ensureVisible(find.byTooltip('重新檢查 yt-dlp'));
    await tester.tap(find.byTooltip('重新檢查 yt-dlp'));
    await tester.pumpAndSettle();
    expect(checks, 2);
    expect(find.text('ffprobe：已就緒（ffprobe version test）'), findsOneWidget);
    expect(find.textContaining('影音合併、音訊擷取或轉檔可能失敗'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Deno presence is shown without affecting tool availability', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ffmpegCheckProvider.overrideWith((ref) async => readyMediaTools),
          ytDlpCheckProvider.overrideWith((ref) async => installation),
          denoCheckProvider.overrideWith((ref) async => r'C:\tools\deno.exe'),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Deno：已找到（選用）'), findsOneWidget);
    expect(find.text(r'C:\tools\deno.exe'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'pending or failed Deno check does not block download or update',
    (tester) async {
      final deno = Completer<String?>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ffmpegCheckProvider.overrideWith((ref) async => readyMediaTools),
            ytDlpCheckProvider.overrideWith((ref) async => installation),
            denoCheckProvider.overrideWith((ref) => deno.future),
          ],
          child: const MyApp(),
        ),
      );
      await tester.pump();
      expect(find.text('Deno：檢查中（選用）…'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.system_update_alt),
            )
            .onPressed,
        isNotNull,
      );
      deno.completeError(StateError('test check failure'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Deno：無法確認'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.system_update_alt),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('missing Deno remains optional and refresh checks again', (
    tester,
  ) async {
    var checks = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ffmpegCheckProvider.overrideWith((ref) async => readyMediaTools),
          ytDlpCheckProvider.overrideWith((ref) async => installation),
          denoCheckProvider.overrideWith((ref) async {
            checks++;
            return null;
          }),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Deno：未找到'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.system_update_alt),
          )
          .onPressed,
      isNotNull,
    );
    await tester.ensureVisible(find.byTooltip('重新檢查 yt-dlp'));
    await tester.tap(find.byTooltip('重新檢查 yt-dlp'));
    await tester.pumpAndSettle();
    expect(checks, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('download action locks form and tool actions until completion', (
    tester,
  ) async {
    final runner = ControlledRunner();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ffmpegCheckProvider.overrideWith((ref) async => readyMediaTools),
          denoCheckProvider.overrideWith((ref) async => null),
          ytDlpCheckProvider.overrideWith((ref) async => installation),
          ytDlpProcessRunnerProvider.overrideWithValue(runner),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'YouTube 影片網址'),
      'https://youtu.be/video',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '儲存資料夾'),
      r'C:\Downloads',
    );
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await runner.started.future;
    expect(runner.calls, 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final scroll = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView).first)
        .controller!;
    expect(
      scroll.position.pixels,
      closeTo(scroll.position.maxScrollExtent, 0.1),
    );
    expect(
      find.byKey(const ValueKey('execution-status-card')).hitTestable(),
      findsOneWidget,
    );
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.system_update_alt),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.refresh))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'YouTube 影片網址'))
          .enabled,
      isFalse,
    );
    runner.emit('YDF_PROGRESS:{"downloaded_bytes":50,"total_bytes":100}');
    await tester.pump();
    expect(find.text('50.0%'), findsOneWidget);
    runner.emit(r'YDF_FILE:C:\Downloads\video.webm');
    runner.result.complete(0);
    await tester.pumpAndSettle();
    expect(find.text('下載完成'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'update button runs self-update without requiring a download form',
    (tester) async {
      final runner = ControlledRunner();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ffmpegCheckProvider.overrideWith((ref) async => readyMediaTools),
            denoCheckProvider.overrideWith((ref) async => null),
            ytDlpCheckProvider.overrideWith((ref) async => installation),
            ytDlpProcessRunnerProvider.overrideWithValue(runner),
          ],
          child: const MyApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithIcon(IconButton, Icons.system_update_alt),
      );
      await tester.tap(
        find.widgetWithIcon(IconButton, Icons.system_update_alt),
      );
      await tester.pump();
      expect(runner.arguments, contains('--update'));
      expect(runner.executable, installation.executablePath);
      expect(find.text('正在更新 yt-dlp…'), findsOneWidget);
      runner.result.complete(0);
      await tester.pumpAndSettle();
      expect(find.text('yt-dlp 已是最新版本（2026.10.11）'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('form edits reach Riverpod and survive format selection', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DownloadPage)),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'YouTube 影片網址'),
      'https://www.youtube.com/watch?v=test',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '儲存資料夾'),
      r'C:\下載 影片',
    );
    await tester.tap(find.byType(DropdownButtonFormField<OutputFormat>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MP3 音訊').last);
    await tester.pumpAndSettle();

    final form = container.read(downloadFormProvider);
    expect(form.url, 'https://www.youtube.com/watch?v=test');
    expect(form.directory, r'C:\下載 影片');
    expect(form.format, OutputFormat.mp3);
    expect(find.text(r'C:\下載 影片'), findsOneWidget);
    expect(find.text('yt-dlp：已就緒（2026.10.11）'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    expect(find.byKey(const ValueKey('execution-status-card')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'folder selection updates the field and cancellation preserves it',
    (tester) async {
      String? selection = r'C:\選擇的資料夾';
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ffmpegCheckProvider.overrideWith((ref) async => readyMediaTools),
            denoCheckProvider.overrideWith((ref) async => null),
            ytDlpCheckProvider.overrideWith((ref) async => installation),
            directoryPickerProvider.overrideWithValue(() async => selection),
          ],
          child: const MyApp(),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DownloadPage)),
      );

      await tester.tap(find.byTooltip('選擇資料夾'));
      await tester.pumpAndSettle();
      expect(find.text(selection), findsOneWidget);
      expect(container.read(downloadFormProvider).directory, selection);

      selection = null;
      await tester.tap(find.byTooltip('選擇資料夾'));
      await tester.pumpAndSettle();
      expect(find.text(r'C:\選擇的資料夾'), findsOneWidget);
      expect(container.read(downloadFormProvider).directory, r'C:\選擇的資料夾');
    },
  );

  testWidgets('small windows can scroll to the status card without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('execution-status-card'));
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    expect(card.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'startup check shows loading then version and path exactly once',
    (tester) async {
      final result = Completer<YtDlpInstallation>();
      var checks = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ffmpegCheckProvider.overrideWith((ref) async => readyMediaTools),
            denoCheckProvider.overrideWith((ref) async => null),
            ytDlpCheckProvider.overrideWith((ref) {
              checks++;
              return result.future;
            }),
          ],
          child: const MyApp(),
        ),
      );
      expect(find.text('yt-dlp：檢查中…'), findsOneWidget);
      result.complete(installation);
      await tester.pumpAndSettle();
      expect(find.text('yt-dlp：已就緒（2026.10.11）'), findsOneWidget);
      expect(find.text(installation.executablePath), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'YouTube 影片網址'),
        'test',
      );
      await tester.pumpAndSettle();
      expect(checks, 1);
      expect(find.text('尚未執行'), findsOneWidget);
    },
  );

  testWidgets('failed check stays visible until user retries', (tester) async {
    var checks = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ffmpegCheckProvider.overrideWith((ref) async => readyMediaTools),
          denoCheckProvider.overrideWith((ref) async => null),
          ytDlpCheckProvider.overrideWith((ref) async {
            checks++;
            if (checks == 1) {
              throw const YtDlpCheckException('找不到 yt-dlp。');
            }
            return installation;
          }),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('找不到 yt-dlp。'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(checks, 1);
    await tester.ensureVisible(find.byTooltip('重新檢查 yt-dlp'));
    await tester.tap(find.byTooltip('重新檢查 yt-dlp'));
    await tester.pumpAndSettle();
    expect(checks, 2);
    expect(find.text('yt-dlp：已就緒（2026.10.11）'), findsOneWidget);
  });
}
