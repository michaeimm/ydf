import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ydf/core/command_runner.dart';
import 'package:ydf/features/download/download_form.dart';
import 'package:ydf/features/tools/yt_dlp_process_runner.dart';

/// Opt-in smoke tests using installed tools and a local HTTP fixture, without
/// downloading YouTube content or updating the user's installed executable.
void main() {
  final executable = Platform.environment['YDF_INTEGRATION_YTDLP'];
  final ffmpeg = Platform.environment['YDF_INTEGRATION_FFMPEG'];
  final enabled = executable != null && ffmpeg != null;
  late Directory root;
  late HttpServer server;

  setUpAll(() async {
    if (!enabled) return;
    root = await Directory.systemTemp.createTemp('ydf integration 中文 ');
    addTearDown(() => root.delete(recursive: true));
    final source = File.fromUri(root.uri.resolve('source.webm'));
    final result = await Process.run(ffmpeg, [
      '-hide_banner',
      '-loglevel',
      'error',
      '-f',
      'lavfi',
      '-i',
      'color=c=black:s=96x64:r=5',
      '-f',
      'lavfi',
      '-i',
      'anullsrc=r=48000:cl=mono',
      '-t',
      '0.4',
      '-c:v',
      'libvpx-vp9',
      '-c:a',
      'libopus',
      source.path,
    ]);
    expect(result.exitCode, 0, reason: result.stderr.toString());
    final content = await source.readAsBytes();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.headers.contentType = ContentType('video', 'webm');
      request.response.contentLength = content.length;
      if (request.method != 'HEAD') request.response.add(content);
      await request.response.close();
    });
  });

  for (final format in OutputFormat.values) {
    test(
      'real yt-dlp downloads and produces ${format.name} output',
      () async {
        final output = await Directory.fromUri(
          root.uri.resolve('${format.name}/'),
        ).create();
        final runner = YtDlpProcessRunner(CommandRunner());
        addTearDown(runner.dispose);
        final lines = <String>[];
        // The local URL deliberately exercises the process layer directly; UI
        // input validation continues to require a YouTube video URL.
        final code = await runner
            .run(
              executable!,
              downloadArguments(
                DownloadForm(
                  url: 'http://127.0.0.1:${server.port}/clip.webm',
                  directory: output.path,
                  format: format,
                ),
              ),
              lines.add,
            )
            .timeout(const Duration(seconds: 40));
        expect(code, 0, reason: lines.join('\n'));
        final saved = lines
            .where((line) => line.startsWith('YDF_FILE:'))
            .single;
        final file = File(saved.substring('YDF_FILE:'.length));
        expect(await file.exists(), isTrue);
        expect(await file.length(), greaterThan(0));
        expect(
          file.path,
          endsWith(
            '.${format == OutputFormat.automatic ? 'webm' : format.name}',
          ),
        );
        expect(lines.any((line) => line.startsWith('YDF_PROGRESS:')), isTrue);
        if (format == OutputFormat.automatic) {
          final modified = await file.lastModified();
          final repeated = <String>[];
          final repeatCode = await runner.run(
            executable,
            downloadArguments(
              DownloadForm(
                url: 'http://127.0.0.1:${server.port}/clip.webm',
                directory: output.path,
                format: format,
              ),
            ),
            repeated.add,
          );
          expect(repeatCode, 0, reason: repeated.join('\n'));
          expect(repeated, contains(saved));
          expect(await file.lastModified(), modified);
        }
        if (format != OutputFormat.automatic) {
          expect(
            lines.any((line) => line.startsWith('YDF_POSTPROCESS:')),
            isTrue,
          );
        }
      },
      skip: enabled
          ? false
          : 'Set YDF_INTEGRATION_YTDLP and YDF_INTEGRATION_FFMPEG to enable.',
    );
  }
}
