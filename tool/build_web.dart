import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final projectRoot = _resolveProjectRoot();
  final settings = await _readSettings(projectRoot);
  final outputPath = _resolveOutputPath(arguments, settings);
  final absoluteOutputPath = _toAbsolutePath(projectRoot.path, outputPath);

  final buildResult = await _runProcess(
    'flutter',
    ['build', 'web', '--release', '--wasm', '--no-web-resources-cdn', '--no-wasm-dry-run', '--output', absoluteOutputPath],
    workingDirectory: projectRoot.path,
  );

  if (buildResult != 0) {
    exit(buildResult);
  }

  exit(buildResult);
}

Directory _resolveProjectRoot() {
  final scriptFile = File.fromUri(Platform.script);
  return scriptFile.parent.parent;
}

Future<Map<String, dynamic>> _readSettings(Directory projectRoot) async {
  final settingsFile = File('${projectRoot.path}${Platform.pathSeparator}tool${Platform.pathSeparator}build_settings.json');

  if (!await settingsFile.exists()) {
    return <String, dynamic>{};
  }

  final content = await settingsFile.readAsString();
  final decoded = jsonDecode(content);

  if (decoded is Map<String, dynamic>) {
    return decoded;
  }

  if (decoded is Map) {
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  throw const FormatException('build_settings.json must contain a JSON object');
}

String _resolveOutputPath(List<String> arguments, Map<String, dynamic> settings) {
  for (var i = 0; i < arguments.length; i++) {
    final argument = arguments[i];

    if (argument.startsWith('--output=')) {
      return argument.substring('--output='.length);
    }

    if (argument == '--output' && i + 1 < arguments.length) {
      return arguments[i + 1];
    }
  }

  final configuredPath = settings['outputPath'];
  if (configuredPath is String && configuredPath.trim().isNotEmpty) {
    return configuredPath;
  }

  return 'build/web';
}

String _toAbsolutePath(String projectRoot, String path) {
  final directory = Directory(path);
  if (directory.isAbsolute) {
    return directory.path;
  }

  return Directory('${projectRoot}${Platform.pathSeparator}$path').path;
}

Future<int> _runProcess(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
}) async {
  try {
    final command = _buildCommand(executable, arguments);
    final process = await Process.start(
      command.executable,
      command.arguments,
      workingDirectory: workingDirectory,
      mode: ProcessStartMode.inheritStdio,
      runInShell: Platform.isWindows,
    );

    return process.exitCode;
  } on ProcessException catch (error) {
    stderr.writeln('Не удалось запустить команду "$executable".');
    stderr.writeln('Проверьте, что она доступна в PATH текущего окружения.');
    stderr.writeln(error.message);
    return 1;
  }
}

({String executable, List<String> arguments}) _buildCommand(
  String executable,
  List<String> arguments,
) {
  if (!Platform.isWindows) {
    return (executable: executable, arguments: arguments);
  }

  final commandLine = [executable, ...arguments].map(_quoteWindowsArgument).join(' ');
  return (
    executable: 'cmd',
    arguments: ['/c', commandLine],
  );
}

String _quoteWindowsArgument(String argument) {
  if (argument.isEmpty) {
    return '""';
  }

  final needsQuotes = argument.contains(' ') || argument.contains('\t') || argument.contains('"');
  if (!needsQuotes) {
    return argument;
  }

  return '"${argument.replaceAll('"', '\\"')}"';
}
