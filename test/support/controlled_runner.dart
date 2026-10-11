import 'dart:async';

import 'package:ydf/core/command_runner.dart';
import 'package:ydf/features/download/download_form.dart';
import 'package:ydf/features/tools/yt_dlp_process_runner.dart';

class ControlledRunner extends YtDlpProcessRunner {
  ControlledRunner() : super(CommandRunner());

  final started = Completer<void>();
  final result = Completer<int>();
  int calls = 0;
  String? executable;
  List<String>? arguments;
  late void Function(String) emit;

  @override
  Future<void> validateDownload(DownloadForm form) async {}

  @override
  Future<int> run(
    String executable,
    List<String> arguments,
    void Function(String) onLine,
  ) {
    calls++;
    this.executable = executable;
    this.arguments = arguments;
    emit = onLine;
    started.complete();
    return result.future;
  }
}
