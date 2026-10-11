import 'dart:io';

Future<void> main(List<String> arguments) async {
  final name = arguments[0];
  switch (arguments[1]) {
    case 'timeout':
      await Future<void>.delayed(const Duration(seconds: 60));
    case 'failure':
      stderr.writeln('test version failure');
      exitCode = 2;
    case 'empty':
      stdout.writeln('unexpected output');
    default:
      stdout.writeln('$name version test-build');
      stdout.writeln('configuration: test');
  }
}
