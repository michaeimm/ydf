import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  stdout.encoding = utf8;
  stderr.encoding = utf8;
  switch (arguments.single) {
    case 'success':
      stdout.writeln('2026.10.11');
    case 'failure':
      stderr.writeln('版本檢查測試錯誤');
      exitCode = 2;
    case 'empty':
      break;
    case 'timeout':
      await Future<void>.delayed(const Duration(minutes: 1));
  }
}
