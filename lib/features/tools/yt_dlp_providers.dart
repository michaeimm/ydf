import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/command_runner.dart';
import 'deno_checker.dart';
import 'ffmpeg_checker.dart';
import 'yt_dlp_checker.dart';

final commandRunnerProvider = Provider<CommandRunner>((ref) => CommandRunner());

final ytDlpCheckerProvider = Provider<YtDlpChecker>((ref) {
  return YtDlpChecker(
    commands: ref.watch(commandRunnerProvider),
    applicationDirectory: File(Platform.resolvedExecutable).parent,
    environment: Platform.environment,
  );
});

// Watching this provider on the first screen starts one check per app session.
// Missing tools should remain visible, rather than trigger automatic retries.
final ytDlpCheckProvider = FutureProvider<YtDlpInstallation>(
  (ref) => ref.watch(ytDlpCheckerProvider).check(),
  retry: (_, _) => null,
);

final denoCheckerProvider = Provider<DenoChecker>((ref) {
  return DenoChecker(
    platform: ref.watch(commandRunnerProvider).platform,
    environment: Platform.environment,
  );
});

final ffmpegCheckerProvider = Provider<FfmpegChecker>(
  (ref) => FfmpegChecker(
    commands: ref.watch(commandRunnerProvider),
    environment: Platform.environment,
  ),
);

final ffmpegCheckProvider = FutureProvider<List<MediaToolStatus>>(
  (ref) => ref.watch(ffmpegCheckerProvider).check(),
  retry: (_, _) => null,
);

// Check PATH immediately, then also check beside the selected Windows yt-dlp.
// This independent result never controls whether downloads/updates are enabled.
final denoCheckProvider = FutureProvider<String?>(
  (ref) => ref
      .watch(denoCheckerProvider)
      .check(
        ytDlpExecutable: ref
            .watch(ytDlpCheckProvider)
            .asData
            ?.value
            .executablePath,
      ),
  retry: (_, _) => null,
);
