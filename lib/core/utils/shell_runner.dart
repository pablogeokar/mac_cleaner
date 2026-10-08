import 'dart:io';
import 'package:path/path.dart' as p;

import '../constants/scan_paths.dart';
import '../../features/scanner/domain/entities/scan_item.dart';

class ShellRunner {
  /// Runs a system command and returns the ProcessResult.
  static Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      final result = await Process.run(
        executable,
        arguments,
        workingDirectory: workingDirectory,
      ).timeout(timeout);
      return result;
    } catch (e) {
      return ProcessResult(-1, -1, '', e.toString());
    }
  }

  /// Calculates the total size of a directory using native `du -sk`.
  static Future<int> getDirectorySizeBytes(String path) async {
    final result = await run('du', ['-sk', path]);
    if (result.exitCode == 0) {
      final output = result.stdout.toString().trim();
      final match = RegExp(r'^(\d+)\s+').firstMatch(output);
      if (match != null) {
        final kb = int.parse(match.group(1)!);
        return kb * 1024;
      }
    }
    return 0;
  }

  /// Verifies if a directory exists and is readable.
  static Future<bool> isAccessible(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) return false;
      // Try listing 1 item to check permissions
      await dir.list().take(1).toList();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Lists files recursively and outputs a Stream of ScanItems.
  static Stream<ScanItem> listFilesRecursive(
    String path, {
    List<String>? extensions,
    DateTime? olderThan,
    int? maxDepth,
    List<String> excludedPaths = const [],
  }) async* {
    final dir = Directory(path);
    if (!await dir.exists()) return;
    if (_isExcluded(path, excludedPaths)) return;

    yield* _listDirHelper(
      dir,
      1,
      maxDepth,
      extensions,
      olderThan,
      excludedPaths,
    );
  }

  static Stream<ScanItem> _listDirHelper(
    Directory dir,
    int currentDepth,
    int? maxDepth,
    List<String>? extensions,
    DateTime? olderThan,
    List<String> excludedPaths,
  ) async* {
    if (maxDepth != null && currentDepth > maxDepth) return;

    Stream<FileSystemEntity> entityStream;
    try {
      entityStream = dir.list(recursive: false, followLinks: false);
    } catch (_) {
      // Permission denied or unreadable directory
      return;
    }

    await for (final entity in entityStream) {
      try {
        final stat = await entity.stat();
        final pathStr = entity.path;
        final name = pathStr.split('/').last;
        if (_isExcluded(pathStr, excludedPaths)) continue;

        if (stat.type == FileSystemEntityType.file) {
          if (extensions != null) {
            bool matches = false;
            for (final ext in extensions) {
              if (pathStr.toLowerCase().endsWith(ext.toLowerCase())) {
                matches = true;
                break;
              }
            }
            if (!matches) continue;
          }

          if (olderThan != null && stat.modified.isAfter(olderThan)) {
            continue;
          }

          yield ScanItem(
            path: pathStr,
            fileName: name,
            sizeBytes: stat.size,
            lastModified: stat.modified,
            lastAccessed: stat.accessed,
            type: ScanItemType.file,
          );
        } else if (stat.type == FileSystemEntityType.directory) {
          // If maxDepth is reached, treat the directory itself as an item
          if (maxDepth != null && currentDepth == maxDepth) {
            final size = await getDirectorySizeBytes(pathStr);
            yield ScanItem(
              path: pathStr,
              fileName: name,
              sizeBytes: size,
              lastModified: stat.modified,
              lastAccessed: stat.accessed,
              type: ScanItemType.directory,
            );
          } else {
            // Otherwise yield nested files
            yield* _listDirHelper(
              Directory(pathStr),
              currentDepth + 1,
              maxDepth,
              extensions,
              olderThan,
              excludedPaths,
            );
          }
        } else if (stat.type == FileSystemEntityType.link) {
          yield ScanItem(
            path: pathStr,
            fileName: name,
            sizeBytes: stat.size,
            lastModified: stat.modified,
            lastAccessed: stat.accessed,
            type: ScanItemType.symlink,
          );
        }
      } catch (_) {
        // Suppress and continue for files with lock/permission errors
      }
    }
  }

  static bool _isExcluded(String candidate, List<String> excludedPaths) {
    final normalizedCandidate = p
        .normalize(ScanPaths.expandPath(candidate))
        .toLowerCase();
    for (final excludedPath in excludedPaths) {
      final normalizedExcluded = p
          .normalize(ScanPaths.expandPath(excludedPath.trim()))
          .toLowerCase();
      if (!p.isAbsolute(normalizedExcluded)) continue;
      if (normalizedCandidate == normalizedExcluded ||
          p.isWithin(normalizedExcluded, normalizedCandidate)) {
        return true;
      }
    }
    return false;
  }
}
