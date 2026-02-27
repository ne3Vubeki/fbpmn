import 'dart:io';
import 'package:crypto/crypto.dart';

void main(List<String> arguments) async {
  print('🔨 Starting Flutter Web files hashing...');
  
  // Параметры командной строки
  String buildPath = 'build/web';
  bool verbose = arguments.contains('--verbose') || arguments.contains('-v');
  
  // Проверяем существование папки сборки
  final webDir = Directory(buildPath);
  if (!await webDir.exists()) {
    print('❌ Error: Build directory not found at $buildPath');
    print('Please run "flutter build web" first');
    exit(1);
  }
  
  // Переходим в папку сборки
  Directory.current = webDir;
  
  // Собираем все файлы для обработки
  final files = <File>[];
  
  // JS файлы (включая .mjs)
  files.addAll(await Directory.current
      .list(recursive: true)
      .where((entity) => entity is File && 
            (entity.path.endsWith('.js') || entity.path.endsWith('.mjs')))
      .cast<File>()
      .toList());
  
  // WASM файлы
  files.addAll(await Directory.current
      .list(recursive: true)
      .where((entity) => entity is File && entity.path.endsWith('.wasm'))
      .cast<File>()
      .toList());
  
  if (verbose) {
    print('📦 Found ${files.length} files to process:');
    for (var file in files) {
      print('  - ${file.path}');
    }
  }
  
  // Карта для хранения старых -> новых имен файлов
  final renameMap = <String, String>{};
  
  // Сначала вычисляем хеши для всех файлов
  for (var file in files) {
    final oldPath = file.path;
    final hash = await _calculateFileHash(file);
    final newPath = _addHashToFilename(oldPath, hash);
    
    renameMap[oldPath] = newPath;
    
    if (verbose) {
      print('🔑 Hash for $oldPath: $hash');
    }
  }
  
  // Обновляем ссылки во всех текстовых файлах
  await _updateReferences(renameMap, verbose);
  
  // Переименовываем файлы
  for (var entry in renameMap.entries) {
    final oldFile = File(entry.key);
    
    if (await oldFile.exists()) {
      if (verbose) {
        print('📝 Renaming: ${entry.key} -> ${entry.value}');
      }
      await oldFile.rename(entry.value);
    }
  }
  
  // Обновляем index.html если нужно
  await _updateIndexHtml(renameMap, verbose);
  
  print('✅ Successfully hashed ${renameMap.length} files!');
}

/// Вычисляет хеш файла (первые 8 символов SHA256)
Future<String> _calculateFileHash(File file) async {
  final content = await file.readAsBytes();
  final hash = sha256.convert(content).toString();
  return hash.substring(0, 8);
}

/// Добавляет хеш к имени файла
String _addHashToFilename(String path, String hash) {
  final directory = path.contains(Platform.pathSeparator)
      ? path.substring(0, path.lastIndexOf(Platform.pathSeparator) + 1)
      : '';
  
  final filename = path.contains(Platform.pathSeparator)
      ? path.substring(path.lastIndexOf(Platform.pathSeparator) + 1)
      : path;
  
  final lastDot = filename.lastIndexOf('.');
  if (lastDot == -1) {
    // Файл без расширения
    return '$directory$filename.$hash';
  }
  
  final name = filename.substring(0, lastDot);
  final ext = filename.substring(lastDot);
  
  return '$directory$name.$hash$ext';
}

/// Обновляет ссылки на переименованные файлы во всех текстовых файлах
Future<void> _updateReferences(Map<String, String> renameMap, bool verbose) async {
  // Получаем все файлы, которые могут содержать ссылки
  final referenceFiles = await Directory.current
      .list(recursive: true)
      .where((entity) => entity is File && 
            (entity.path.endsWith('.html') || 
             entity.path.endsWith('.js') || 
             entity.path.endsWith('.mjs') ||
             entity.path.endsWith('.json')))
      .cast<File>()
      .toList();
  
  for (var file in referenceFiles) {
    if (verbose) {
      print('🔍 Checking references in: ${file.path}');
    }
    
    try {
      String content = await file.readAsString();
      bool modified = false;
      
      // Заменяем все вхождения старых имен на новые
      for (var entry in renameMap.entries) {
        final oldName = entry.key.contains(Platform.pathSeparator)
            ? entry.key.substring(entry.key.lastIndexOf(Platform.pathSeparator) + 1)
            : entry.key;
        
        final newName = entry.value.contains(Platform.pathSeparator)
            ? entry.value.substring(entry.value.lastIndexOf(Platform.pathSeparator) + 1)
            : entry.value;
        
        // Экранируем специальные символы для RegExp
        final escapedOldName = RegExp.escape(oldName);
        
        if (content.contains(escapedOldName)) {
          content = content.replaceAllMapped(
            RegExp(escapedOldName),
            (match) => newName
          );
          modified = true;
          
          if (verbose) {
            print('  ↳ Replaced "$oldName" with "$newName" in ${file.path}');
          }
        }
      }
      
      if (modified) {
        await file.writeAsString(content);
      }
    } catch (e) {
      print('⚠️  Warning: Could not process ${file.path}: $e');
    }
  }
}

/// Специальная обработка index.html для обновления ссылок на скрипты
Future<void> _updateIndexHtml(Map<String, String> renameMap, bool verbose) async {
  final indexPath = 'index.html';
  final indexFile = File(indexPath);
  
  if (!await indexFile.exists()) {
    return;
  }
  
  String content = await indexFile.readAsString();
  bool modified = false;
  
  // Ищем все теги <script src="...">
  final scriptRegex = RegExp(r'<script\s+[^>]*src="([^"]+)"');
  final matches = scriptRegex.allMatches(content);
  
  for (var match in matches) {
    final scriptPath = match.group(1);
    if (scriptPath == null) continue;
    
    // Получаем имя файла из пути
    final scriptFilename = scriptPath.contains('/')
        ? scriptPath.substring(scriptPath.lastIndexOf('/') + 1)
        : scriptPath;
    
    // Ищем соответствующее переименование
    for (var entry in renameMap.entries) {
      final oldName = entry.key.contains(Platform.pathSeparator)
          ? entry.key.substring(entry.key.lastIndexOf(Platform.pathSeparator) + 1)
          : entry.key;
      
      final newName = entry.value.contains(Platform.pathSeparator)
          ? entry.value.substring(entry.value.lastIndexOf(Platform.pathSeparator) + 1)
          : entry.value;
      
      if (scriptFilename == oldName) {
        // Заменяем путь в src
        final newScriptPath = scriptPath.replaceAll(oldName, newName);
        content = content.replaceAll('src="$scriptPath"', 'src="$newScriptPath"');
        modified = true;
        
        if (verbose) {
          print('🌐 Updated script reference in index.html: $scriptPath -> $newScriptPath');
        }
      }
    }
  }
  
  if (modified) {
    await indexFile.writeAsString(content);
    print('📄 Updated index.html');
  }
}