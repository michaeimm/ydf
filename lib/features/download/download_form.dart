import 'package:flutter_riverpod/flutter_riverpod.dart';

enum OutputFormat {
  automatic('自動（不指定轉檔）'),
  mp4('MP4 影片'),
  mkv('MKV 影片'),
  mp3('MP3 音訊'),
  m4a('M4A 音訊');

  const OutputFormat(this.label);

  final String label;
}

class DownloadForm {
  const DownloadForm({
    this.url = '',
    this.directory = '',
    this.format = OutputFormat.automatic,
  });

  final String url;
  final String directory;
  final OutputFormat format;

  DownloadForm copyWith({
    String? url,
    String? directory,
    OutputFormat? format,
  }) {
    return DownloadForm(
      url: url ?? this.url,
      directory: directory ?? this.directory,
      format: format ?? this.format,
    );
  }
}

final downloadFormProvider =
    NotifierProvider<DownloadFormNotifier, DownloadForm>(
      DownloadFormNotifier.new,
    );

class DownloadFormNotifier extends Notifier<DownloadForm> {
  @override
  DownloadForm build() => const DownloadForm();

  void setUrl(String url) => state = state.copyWith(url: url);

  void setDirectory(String directory) =>
      state = state.copyWith(directory: directory);

  void setFormat(OutputFormat format) => state = state.copyWith(format: format);
}
