import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'execution_controller.dart';
import 'yt_dlp_checker.dart';
import 'yt_dlp_providers.dart';

class YtDlpStatus extends ConsumerWidget {
  const YtDlpStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final check = ref.watch(ytDlpCheckProvider);
    final deno = ref.watch(denoCheckProvider);
    final theme = Theme.of(context);
    final busy = ref.watch(executionProvider.select((state) => state.isBusy));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Icon(Icons.terminal, size: 18),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              check.when(
                skipLoadingOnRefresh: false,
                loading: () => const Text('yt-dlp：檢查中…'),
                data: (installation) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('yt-dlp：已就緒（${installation.version}）'),
                    const SizedBox(height: 4),
                    SelectableText(
                      installation.executablePath,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                error: (error, _) {
                  final path = error is YtDlpCheckException
                      ? error.executablePath
                      : null;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'yt-dlp：檢查失敗',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                      const SizedBox(height: 4),
                      Text(error.toString()),
                      if (path != null) ...[
                        const SizedBox(height: 4),
                        SelectableText(path, style: theme.textTheme.bodySmall),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              deno.when(
                skipLoadingOnRefresh: false,
                loading: () => const Text('Deno：檢查中（選用）…'),
                data: (path) => path == null
                    ? const Text('Deno：未找到（選用）。建議安裝以完整支援 YouTube 下載，仍可嘗試下載。')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Deno：已找到（選用）'),
                          const SizedBox(height: 4),
                          SelectableText(
                            path,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                error: (error, _) => Text('Deno：無法確認（選用），仍可嘗試下載。\n$error'),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: '重新檢查 yt-dlp',
          onPressed: check.isLoading || busy
              ? null
              : () {
                  ref.invalidate(ytDlpCheckProvider);
                  ref.invalidate(denoCheckProvider);
                },
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          tooltip: '更新 yt-dlp',
          onPressed: busy || check.isLoading || check.asData == null
              ? null
              : () => ref.read(executionProvider.notifier).update(),
          icon: const Icon(Icons.system_update_alt),
        ),
      ],
    );
  }
}
