import 'package:path/path.dart' as path;

String? validateVideoUrl(String? input) {
  try {
    final value = (input ?? '').trim();
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort) {
      return '請輸入有效的 YouTube 影片網址。';
    }
    final segments = uri.pathSegments;
    final isShortLink =
        ['youtu.be', 'www.youtu.be'].contains(uri.host) &&
        segments.length == 1 &&
        segments.first.isNotEmpty;
    final isYouTube = [
      'youtube.com',
      'www.youtube.com',
      'm.youtube.com',
      'music.youtube.com',
    ].contains(uri.host);
    final isVideo =
        (uri.path == '/watch' && (uri.queryParameters['v'] ?? '').isNotEmpty) ||
        (segments.length == 2 &&
            ['shorts', 'live', 'embed'].contains(segments.first) &&
            segments.last.isNotEmpty);
    return isShortLink || (isYouTube && isVideo)
        ? null
        : '請輸入單一 YouTube 影片網址，不支援頻道或播放清單。';
  } on FormatException {
    return '請輸入有效的 YouTube 影片網址。';
  }
}

String? validateDownloadDirectory(String? input) {
  final value = (input ?? '').trim();
  if (value.isEmpty) return '請選擇儲存資料夾。';
  if (!path.isAbsolute(value)) return '請輸入資料夾的完整絕對路徑。';
  return null;
}
