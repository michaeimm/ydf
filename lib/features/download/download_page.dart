import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../tools/execution_card.dart';
import '../tools/execution_controller.dart';
import '../tools/yt_dlp_providers.dart';
import '../tools/yt_dlp_status.dart';
import 'download_form.dart';
import 'download_validation.dart';

final directoryPickerProvider = Provider<Future<String?> Function()>((ref) {
  return () => getDirectoryPath(confirmButtonText: '選擇此資料夾');
});

class DownloadPage extends ConsumerStatefulWidget {
  const DownloadPage({super.key});

  @override
  ConsumerState<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends ConsumerState<DownloadPage> {
  late final TextEditingController _urlController;
  late final TextEditingController _directoryController;
  final _scrollController = ScrollController();
  bool _choosingDirectory = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final form = ref.read(downloadFormProvider);
    _urlController = TextEditingController(text: form.url);
    _directoryController = TextEditingController(text: form.directory);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _directoryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _chooseDirectory() async {
    setState(() => _choosingDirectory = true);
    try {
      final directory = await ref.read(directoryPickerProvider)();
      if (!mounted || directory == null || ref.read(executionProvider).isBusy) {
        return;
      }
      _directoryController.text = directory;
      ref.read(downloadFormProvider.notifier).setDirectory(directory);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('無法開啟資料夾選擇視窗，請手動輸入路徑。')));
    } finally {
      if (mounted) setState(() => _choosingDirectory = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(downloadFormProvider);
    final notifier = ref.read(downloadFormProvider.notifier);
    final theme = Theme.of(context);
    final busy = ref.watch(executionProvider.select((state) => state.isBusy));
    final check = ref.watch(ytDlpCheckProvider);
    final ready = !check.isLoading && check.asData != null;
    ref.listen(
      executionProvider.select((state) => (state.kind, state.isBusy)),
      (previous, next) {
        if (next.$1 != ExecutionKind.download ||
            !next.$2 ||
            previous?.$2 == true) {
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scrollController.hasClients) return;
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('YT-dlp 下載小工具'),
        backgroundColor: const Color(0xFFAD1F1F),
        notificationPredicate: (_) => false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(24),
          child: Align(
            alignment: AlignmentGeometry.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('下載 YouTube 影片', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    const Text('輸入影片網址、選擇儲存位置與輸出格式。'),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _urlController,
                      enabled: !busy,
                      validator: validateVideoUrl,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      onChanged: notifier.setUrl,
                      decoration: const InputDecoration(
                        labelText: 'YouTube 影片網址',
                        hintText: 'https://www.youtube.com/watch?v=…',
                        prefixIcon: Icon(Icons.link),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _directoryController,
                      enabled: !busy,
                      validator: validateDownloadDirectory,
                      autocorrect: false,
                      onChanged: notifier.setDirectory,
                      decoration: InputDecoration(
                        labelText: '儲存資料夾',
                        hintText: r'C:\Users\你的名稱\Downloads',
                        helperText: '輸入完整路徑，或點選右側按鈕選擇資料夾。',
                        prefixIcon: const Icon(Icons.folder_outlined),
                        suffixIcon: IconButton(
                          tooltip: '選擇資料夾',
                          onPressed: _choosingDirectory || busy
                              ? null
                              : _chooseDirectory,
                          icon: const Icon(Icons.folder_open),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<OutputFormat>(
                      initialValue: form.format,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: '轉檔／輸出格式',
                        prefixIcon: Icon(Icons.video_file_outlined),
                      ),
                      items: [
                        for (final format in OutputFormat.values)
                          DropdownMenuItem(
                            value: format,
                            child: Text(format.label),
                          ),
                      ],
                      onChanged: busy
                          ? null
                          : (format) {
                              if (format != null) notifier.setFormat(format);
                            },
                    ),
                    const SizedBox(height: 20),
                    const YtDlpStatus(),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: !ready || busy || _choosingDirectory
                            ? null
                            : () {
                                if (_formKey.currentState!.validate()) {
                                  ref
                                      .read(executionProvider.notifier)
                                      .download(ref.read(downloadFormProvider));
                                }
                              },
                        icon: const Icon(Icons.download),
                        label: const Text('開始下載'),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const ExecutionCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
