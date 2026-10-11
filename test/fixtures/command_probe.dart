import 'dart:convert';
import 'dart:io';

void main(List<String> arguments) {
  stdout.encoding = utf8;
  stderr.encoding = utf8;
  stdout.writeln(
    jsonEncode({
      'arguments': arguments,
      'workingDirectory': Directory.current.path,
      'environment': Platform.environment['YDF_COMMAND_TEST'],
    }),
  );
  stderr.writeln('測試 stderr');
  exitCode = 7;
}
