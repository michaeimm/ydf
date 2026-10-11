import 'dart:convert';
import 'dart:io';

/// Desktop platforms supported by the command layer.
enum CommandPlatform {
  windows,
  macos,
  linux;

  static CommandPlatform fromOperatingSystem(String operatingSystem) {
    return switch (operatingSystem) {
      'windows' => windows,
      'macos' => macos,
      'linux' => linux,
      _ => throw UnsupportedError(
        'Command execution is not supported on $operatingSystem.',
      ),
    };
  }
}

/// Executes native programs without constructing shell command strings.
///
/// Prefer absolute executable paths. Executable lookup follows the host OS;
/// on Windows, [workingDirectory] and a supplied PATH do not affect lookup.
abstract class CommandRunner {
  factory CommandRunner() => _IoCommandRunner(
    CommandPlatform.fromOperatingSystem(Platform.operatingSystem),
  );

  CommandPlatform get platform;

  /// Runs a short command to completion, collecting its output.
  ///
  /// A nonzero exit code is returned unchanged. Launch failures throw
  /// [ProcessException]. Output defaults to UTF-8; callers can override it.
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Encoding stdoutEncoding = utf8,
    Encoding stderrEncoding = utf8,
  });

  /// Starts a streaming command, such as a download.
  ///
  /// The caller owns the returned process: consume both stdout and stderr,
  /// close stdin when unused, and await exitCode. Streams contain raw bytes.
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  });
}

class _IoCommandRunner implements CommandRunner {
  _IoCommandRunner(this.platform);

  @override
  final CommandPlatform platform;

  void _validateExecutable(String executable) {
    if (executable.trim().isEmpty) {
      throw ArgumentError.value(executable, 'executable', 'Must not be empty.');
    }
    final name = executable.toLowerCase();
    if (platform == CommandPlatform.windows &&
        (name.endsWith('.bat') || name.endsWith('.cmd'))) {
      throw ArgumentError.value(
        executable,
        'executable',
        'Use a native executable instead of a Windows batch script.',
      );
    }
  }

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Encoding stdoutEncoding = utf8,
    Encoding stderrEncoding = utf8,
  }) async {
    _validateExecutable(executable);
    return Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: false,
      stdoutEncoding: stdoutEncoding,
      stderrEncoding: stderrEncoding,
    );
  }

  @override
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    _validateExecutable(executable);
    return Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: false,
    );
  }
}
