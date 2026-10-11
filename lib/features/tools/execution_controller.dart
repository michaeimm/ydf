import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../download/download_form.dart';
import 'yt_dlp_process_runner.dart';
import 'yt_dlp_providers.dart';

enum ExecutionKind { download, update }

enum ExecutionPhase {
  idle,
  preparing,
  downloading,
  processing,
  updating,
  completed,
  failed,
}

class ExecutionState {
  const ExecutionState({
    this.kind = ExecutionKind.download,
    this.phase = ExecutionPhase.idle,
    this.message = '尚未執行',
    this.progress,
    this.logs = const [],
  });

  final ExecutionKind kind;
  final ExecutionPhase phase;
  final String message;
  final double? progress;
  final List<String> logs;
  bool get isBusy => [
    ExecutionPhase.preparing,
    ExecutionPhase.downloading,
    ExecutionPhase.processing,
    ExecutionPhase.updating,
  ].contains(phase);
}

final executionProvider = NotifierProvider<ExecutionController, ExecutionState>(
  ExecutionController.new,
);

class ExecutionController extends Notifier<ExecutionState> {
  @override
  ExecutionState build() => const ExecutionState();

  Future<void> download(DownloadForm form) =>
      _execute(ExecutionKind.download, downloadArguments(form), form: form);

  Future<void> update() => _execute(ExecutionKind.update, updateArguments);

  Future<void> _execute(
    ExecutionKind kind,
    List<String> arguments, {
    DownloadForm? form,
  }) async {
    if (state.isBusy) return;
    final check = ref.read(ytDlpCheckProvider);
    final installation = check.asData?.value;
    if (check.isLoading || installation == null) return;
    state = ExecutionState(
      kind: kind,
      phase: kind == ExecutionKind.download
          ? ExecutionPhase.preparing
          : ExecutionPhase.updating,
      message: kind == ExecutionKind.download ? '準備下載…' : '正在更新 yt-dlp…',
    );
    try {
      final runner = ref.read(ytDlpProcessRunnerProvider);
      if (form != null) await runner.validateDownload(form);
      if (!ref.mounted) return;
      _append('執行檔：${installation.executablePath}');
      var outputReported = false;
      final code = await runner.run(installation.executablePath, arguments, (
        line,
      ) {
        if (line.startsWith('YDF_FILE:') &&
            line.substring('YDF_FILE:'.length).trim().isNotEmpty) {
          outputReported = true;
        }
        _onLine(line);
      });
      if (!ref.mounted) return;
      if (code != 0) throw StateError('程序以退出碼 $code 結束，請查看執行訊息。');
      if (kind == ExecutionKind.download && !outputReported) {
        throw StateError('yt-dlp 未回報輸出檔案。影片可能被略過，請查看執行訊息。');
      }
      var message = '下載完成';
      if (kind == ExecutionKind.update) {
        ref.invalidate(ytDlpCheckProvider);
        final updated = await ref.read(ytDlpCheckProvider.future);
        if (!ref.mounted) return;
        message = updated.version == installation.version
            ? 'yt-dlp 已是最新版本（${updated.version}）'
            : 'yt-dlp 更新完成（${updated.version}）';
      }
      state = ExecutionState(
        kind: kind,
        phase: ExecutionPhase.completed,
        message: message,
        logs: state.logs,
      );
    } catch (error) {
      if (!ref.mounted) return;
      final detail = switch (error) {
        FormatException() => error.message,
        FileSystemException() => '資料夾無法存取或寫入：${error.message}',
        ProcessException() => '無法啟動 yt-dlp：${error.message}',
        _ => error.toString(),
      };
      _append('錯誤：$detail');
      state = ExecutionState(
        kind: kind,
        phase: ExecutionPhase.failed,
        message: kind == ExecutionKind.download ? '下載失敗' : 'yt-dlp 更新失敗',
        logs: state.logs,
      );
      if (kind == ExecutionKind.update) ref.invalidate(ytDlpCheckProvider);
    }
  }

  void _onLine(String line) {
    if (!ref.mounted || line.isEmpty) return;
    if (state.kind == ExecutionKind.download &&
        line.startsWith('YDF_PROGRESS:')) {
      try {
        final data = jsonDecode(line.substring('YDF_PROGRESS:'.length)) as Map;
        final downloaded = data['downloaded_bytes'];
        final total = data['total_bytes'] ?? data['total_bytes_estimate'];
        final progress = downloaded is num && total is num && total > 0
            ? (downloaded / total).clamp(0.0, 1.0)
            : null;
        state = ExecutionState(
          kind: state.kind,
          phase: ExecutionPhase.downloading,
          message: '下載中（目前檔案）',
          progress: progress,
          logs: state.logs,
        );
        return;
      } catch (_) {
        // Keep unrecognized output available for diagnosis.
      }
    }
    if (line.startsWith('YDF_POSTPROCESS:')) {
      state = ExecutionState(
        kind: state.kind,
        phase: ExecutionPhase.processing,
        message: '合併／轉檔中…',
        logs: state.logs,
      );
      return;
    }
    _append(
      line.startsWith('YDF_FILE:')
          ? '儲存檔案：${line.substring('YDF_FILE:'.length)}'
          : line,
    );
  }

  void _append(String line) {
    final logs = [...state.logs, line];
    state = ExecutionState(
      kind: state.kind,
      phase: state.phase,
      message: state.message,
      progress: state.progress,
      logs: List.unmodifiable(
        logs.length > 200 ? logs.sublist(logs.length - 200) : logs,
      ),
    );
  }
}
