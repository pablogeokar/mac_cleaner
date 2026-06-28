import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';

import '../../../../core/constants/scan_paths.dart';
import '../../../../core/utils/shell_runner.dart';
import '../../domain/entities/deletion_safety_guard.dart';
import '../../domain/entities/scan_category.dart';
import '../../domain/entities/scan_item.dart';
import '../../domain/entities/scan_progress.dart';
import '../../domain/repositories/file_scanner_repository.dart';

class FileScannerRepositoryImpl implements FileScannerRepository {
  static const _channel = MethodChannel('macsweep/recycle');

  @override
  Future<void> deleteItems(
    List<ScanItem> items, {
    required bool permanent,
  }) async {
    final pathsToDelete = <String>[];
    for (final item in items) {
      if (DeletionSafetyGuard.isSafeToDelete(item.path)) {
        pathsToDelete.add(item.path);
      }
    }

    if (pathsToDelete.isEmpty) return;

    if (permanent) {
      for (final path in pathsToDelete) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete(recursive: true);
            continue;
          }
          final dir = Directory(path);
          if (await dir.exists()) {
            await dir.delete(recursive: true);
          }
        } catch (_) {
          // Suppress errors for single files
        }
      }
    } else {
      try {
        await _channel.invokeMethod('recycle', pathsToDelete);
      } on PlatformException catch (e) {
        throw Exception('Failed to move files to Trash: ${e.message}');
      }
    }
  }

  @override
  Stream<ScanProgress> scanCategory(
    ScanCategoryType category, {
    int largeFileThresholdBytes = 500 * 1024 * 1024,
    int tempFileAgeHours = 48,
    int systemCacheAgeDays = 7,
  }) async* {
    yield ScanProgress(
      category: category,
      progress: 0.0,
      currentPath: 'Inicializando...',
      itemsFound: 0,
      bytesFound: 0,
      isComplete: false,
      items: const [],
    );

    final List<ScanItem> items = [];
    int totalBytes = 0;

    try {
      switch (category) {
        case ScanCategoryType.systemCache:
          final cachePaths = List<String>.from(ScanPaths.systemCachePaths);

          // Resolve /private/var/folders/**/C/
          final systemTemp = Directory.systemTemp.path;
          if (systemTemp.endsWith('/T')) {
            final cacheFolder =
                '${systemTemp.substring(0, systemTemp.length - 2)}/C';
            cachePaths.add(cacheFolder);
          }

          final limitDate = DateTime.now().subtract(
            Duration(days: systemCacheAgeDays),
          );

          for (final rawPath in cachePaths) {
            final path = ScanPaths.expandPath(rawPath);
            if (!await ShellRunner.isAccessible(path)) continue;

            yield ScanProgress(
              category: category,
              progress: 0.3,
              currentPath: 'Escaneando: $path',
              itemsFound: items.length,
              bytesFound: totalBytes,
              isComplete: false,
              items: items,
            );

            await for (final item in ShellRunner.listFilesRecursive(
              path,
              olderThan: limitDate,
            )) {
              if (item.path.contains('com.apple.Safari')) continue;
              items.add(item);
              totalBytes += item.sizeBytes;
            }
          }
          break;

        case ScanCategoryType.systemLogs:
          final logPaths = List<String>.from(ScanPaths.systemLogsPaths);

          // Find Logs under App Support: ~/Library/Application Support/*/Logs
          final appSupportPath = ScanPaths.expandPath(
            '~/Library/Application Support',
          );
          final appSupportDir = Directory(appSupportPath);
          if (await appSupportDir.exists()) {
            try {
              await for (final entity in appSupportDir.list(recursive: false)) {
                if (entity is Directory) {
                  final logsPath = p.join(entity.path, 'Logs');
                  if (await Directory(logsPath).exists()) {
                    logPaths.add(logsPath);
                  }
                }
              }
            } catch (_) {}
          }

          final limitDate = DateTime.now().subtract(const Duration(hours: 24));

          for (final rawPath in logPaths) {
            final path = ScanPaths.expandPath(rawPath);
            if (!await ShellRunner.isAccessible(path)) continue;

            yield ScanProgress(
              category: category,
              progress: 0.4,
              currentPath: 'Escaneando logs em: $path',
              itemsFound: items.length,
              bytesFound: totalBytes,
              isComplete: false,
              items: items,
            );

            await for (final item in ShellRunner.listFilesRecursive(
              path,
              extensions: ScanPaths.logExtensions,
              olderThan: limitDate,
            )) {
              items.add(item);
              totalBytes += item.sizeBytes;
            }
          }
          break;

        case ScanCategoryType.temporaryFiles:
          final tempPaths = List<String>.from(ScanPaths.temporaryPaths);
          final limitDate = DateTime.now().subtract(
            Duration(hours: tempFileAgeHours),
          );

          // Scan system-wide temporary folders
          for (final rawPath in tempPaths) {
            final path = ScanPaths.expandPath(rawPath);
            if (!await ShellRunner.isAccessible(path)) continue;

            await for (final item in ShellRunner.listFilesRecursive(
              path,
              olderThan: limitDate,
            )) {
              items.add(item);
              totalBytes += item.sizeBytes;
            }
          }

          // Scan temp files in Downloads
          final downloadsPath = ScanPaths.expandPath('~/Downloads');
          if (await Directory(downloadsPath).exists()) {
            await for (final item in ShellRunner.listFilesRecursive(
              downloadsPath,
              extensions: ScanPaths.tempDownloadExtensions,
              olderThan: limitDate,
            )) {
              items.add(item);
              totalBytes += item.sizeBytes;
            }
          }
          break;

        case ScanCategoryType.trash:
          final trashPath = ScanPaths.expandPath('~/.Trash');
          if (await Directory(trashPath).exists()) {
            await for (final item in ShellRunner.listFilesRecursive(
              trashPath,
              maxDepth: 1, // Treat top-level items as single deletable entries
            )) {
              items.add(item);
              totalBytes += item.sizeBytes;
            }
          }
          break;

        case ScanCategoryType.appCache:
          // Xcode, npm, yarn, pip, Gradle, Maven, CocoaPods, Carthage, Android Studio, Simulator iOS, Docker

          // Homebrew cache
          String brewCachePath = ScanPaths.expandPath(
            '~/Library/Caches/Homebrew',
          );
          final brewResult = await ShellRunner.run('brew', ['--cache']);
          if (brewResult.exitCode == 0) {
            brewCachePath = brewResult.stdout.toString().trim();
          }

          final appCaches = Map<String, List<String>>.from(
            ScanPaths.appCachePaths,
          );
          appCaches['Homebrew'] = [brewCachePath];

          // Android Studio Application Support dynamic path:
          final googleSupportPath = ScanPaths.expandPath(
            ScanPaths.androidStudioAppSupportPattern,
          );
          final googleSupportDir = Directory(googleSupportPath);
          if (await googleSupportDir.exists()) {
            try {
              await for (final entity in googleSupportDir.list(
                recursive: false,
              )) {
                if (entity is Directory &&
                    p.basename(entity.path).startsWith('AndroidStudio')) {
                  appCaches['Android Studio'] =
                      (appCaches['Android Studio'] ?? [])..add(entity.path);
                }
              }
            } catch (_) {}
          }

          int processedCaches = 0;
          for (final appName in appCaches.keys) {
            final paths = appCaches[appName]!;
            final progressVal =
                0.1 + (0.8 * (processedCaches / appCaches.length));
            yield ScanProgress(
              category: category,
              progress: progressVal,
              currentPath: 'Varrendo cache do $appName...',
              itemsFound: items.length,
              bytesFound: totalBytes,
              isComplete: false,
              items: items,
            );

            for (final rawPath in paths) {
              final path = ScanPaths.expandPath(rawPath);
              if (!await Directory(path).exists()) continue;

              // Scan direct children as items
              await for (final item in ShellRunner.listFilesRecursive(
                path,
                maxDepth: 2,
              )) {
                items.add(item);
                totalBytes += item.sizeBytes;
              }
            }
            processedCaches++;
          }
          break;

        case ScanCategoryType.largeFiles:
          for (final rawPath in ScanPaths.userRoots) {
            final path = ScanPaths.expandPath(rawPath);
            if (!await Directory(path).exists()) continue;

            yield ScanProgress(
              category: category,
              progress: 0.5,
              currentPath: 'Buscando arquivos grandes em: $path',
              itemsFound: items.length,
              bytesFound: totalBytes,
              isComplete: false,
              items: items,
            );

            await for (final item in ShellRunner.listFilesRecursive(path)) {
              if (item.sizeBytes >= largeFileThresholdBytes) {
                // Large files should NOT be auto-selected
                items.add(
                  item.copyWith(
                    isSelected: false,
                    isSafeToDelete: true,
                    reason: 'Arquivo maior que 500 MB',
                  ),
                );
                totalBytes += item.sizeBytes;
              }
            }
          }
          break;

        case ScanCategoryType.duplicates:
          // Detect duplicates in Downloads, Desktop, Documents
          final allCandidates = <ScanItem>[];
          for (final rawPath in ScanPaths.userRoots) {
            final path = ScanPaths.expandPath(rawPath);
            if (!await Directory(path).exists()) continue;

            await for (final item in ShellRunner.listFilesRecursive(path)) {
              allCandidates.add(item);
            }
          }

          // Group by size first
          final sizeGroups = <int, List<ScanItem>>{};
          for (final item in allCandidates) {
            sizeGroups.putIfAbsent(item.sizeBytes, () => []).add(item);
          }

          final potentialDuplicates = sizeGroups.values
              .where((group) => group.length > 1)
              .expand((g) => g)
              .toList();

          int hashedCount = 0;
          final hashes = <String, List<ScanItem>>{};

          for (final item in potentialDuplicates) {
            final progressVal =
                0.1 + (0.8 * (hashedCount / potentialDuplicates.length));
            yield ScanProgress(
              category: category,
              progress: progressVal,
              currentPath: 'Analisando duplicatas: ${item.fileName}',
              itemsFound: items.length,
              bytesFound: totalBytes,
              isComplete: false,
              items: items,
            );

            // Compute MD5 hash with custom streaming reader
            final hash = await _getFileMd5(item.path);
            if (hash.isNotEmpty) {
              hashes.putIfAbsent(hash, () => []).add(item);
            }
            hashedCount++;
          }

          // Add duplicates to items
          for (final entry in hashes.entries) {
            final duplicatesList = entry.value;
            if (duplicatesList.length > 1) {
              // Sort by modification date
              duplicatesList.sort(
                (a, b) => a.lastModified.compareTo(b.lastModified),
              );
              for (int i = 1; i < duplicatesList.length; i++) {
                final copy = duplicatesList[i];
                items.add(
                  copy.copyWith(
                    isSelected: false,
                    reason: 'Cópia duplicada de ${duplicatesList[0].fileName}',
                  ),
                );
                totalBytes += copy.sizeBytes;
              }
            }
          }
          break;

        case ScanCategoryType.appResiduals:
          // 1. Get installed apps
          final installedApps = <String>{};
          for (final root in [
            '/Applications',
            ScanPaths.expandPath('~/Applications'),
          ]) {
            final dir = Directory(root);
            if (await dir.exists()) {
              try {
                await for (final entity in dir.list(recursive: false)) {
                  if (entity is Directory && entity.path.endsWith('.app')) {
                    final name = p
                        .basenameWithoutExtension(entity.path)
                        .toLowerCase();
                    installedApps.add(name);
                  }
                }
              } catch (_) {}
            }
          }

          // Check Caskroom
          final caskroom = Directory('/usr/local/Caskroom');
          if (await caskroom.exists()) {
            try {
              await for (final entity in caskroom.list(recursive: false)) {
                installedApps.add(p.basename(entity.path).toLowerCase());
              }
            } catch (_) {}
          }

          // 2. Scan App Support, Preferences, LaunchAgents, Containers
          int processedRoots = 0;
          for (final rawPath in ScanPaths.residualSearchPaths) {
            final path = ScanPaths.expandPath(rawPath);
            if (!await Directory(path).exists()) continue;

            final progressVal =
                0.1 +
                (0.8 * (processedRoots / ScanPaths.residualSearchPaths.length));
            yield ScanProgress(
              category: category,
              progress: progressVal,
              currentPath: 'Analisando resíduos em: $path',
              itemsFound: items.length,
              bytesFound: totalBytes,
              isComplete: false,
              items: items,
            );

            try {
              await for (final entity in Directory(
                path,
              ).list(recursive: false)) {
                final name = p.basename(entity.path).toLowerCase();

                bool isOrphan = true;
                for (final app in installedApps) {
                  if (name.contains(app) || app.contains(name)) {
                    isOrphan = false;
                    break;
                  }
                }

                if (name.startsWith('com.apple.') ||
                    name.startsWith('apple.')) {
                  isOrphan = false;
                }

                if (isOrphan) {
                  final stat = await entity.stat();
                  final size = entity is Directory
                      ? await ShellRunner.getDirectorySizeBytes(entity.path)
                      : stat.size;

                  items.add(
                    ScanItem(
                      path: entity.path,
                      fileName: p.basename(entity.path),
                      sizeBytes: size,
                      lastModified: stat.modified,
                      lastAccessed: stat.accessed,
                      type: entity is Directory
                          ? ScanItemType.directory
                          : ScanItemType.file,
                      isSelected: false, // Require confirmation
                      reason: 'Pasta residual órfã',
                    ),
                  );
                  totalBytes += size;
                }
              }
            } catch (_) {}
            processedRoots++;
          }
          break;

        case ScanCategoryType.duplicateFonts:
          final fontLocations = [
            ScanPaths.expandPath('~/Library/Fonts'),
            '/Library/Fonts',
            ScanPaths.systemFontPath,
          ];

          final fontFiles = <String, List<ScanItem>>{};

          for (final fontDir in fontLocations) {
            if (!await Directory(fontDir).exists()) continue;

            await for (final item in ShellRunner.listFilesRecursive(
              fontDir,
              extensions: ['.ttf', '.otf'],
            )) {
              fontFiles
                  .putIfAbsent(item.fileName.toLowerCase(), () => [])
                  .add(item);
            }
          }

          for (final entry in fontFiles.entries) {
            final duplicatesList = entry.value;
            if (duplicatesList.length > 1) {
              duplicatesList.sort((a, b) {
                int scoreA = a.path.startsWith('/System')
                    ? 3
                    : a.path.startsWith('/Library')
                    ? 2
                    : 1;
                int scoreB = b.path.startsWith('/System')
                    ? 3
                    : b.path.startsWith('/Library')
                    ? 2
                    : 1;
                return scoreB.compareTo(scoreA);
              });

              for (int i = 1; i < duplicatesList.length; i++) {
                final copy = duplicatesList[i];
                final systemFont = copy.path.startsWith('/System');

                items.add(
                  copy.copyWith(
                    isSelected: false,
                    isSafeToDelete: !systemFont,
                    reason: systemFont
                        ? 'Fonte do sistema duplicada (Leitura apenas)'
                        : 'Fonte duplicada instalada em múltiplos locais',
                  ),
                );
                totalBytes += copy.sizeBytes;
              }
            }
          }
          break;
      }
    } catch (e) {
      // Catch exceptions
    }

    yield ScanProgress(
      category: category,
      progress: 1.0,
      currentPath: 'Varredura concluída!',
      itemsFound: items.length,
      bytesFound: totalBytes,
      isComplete: true,
      items: items,
    );
  }

  Future<String> _getFileMd5(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return '';
    try {
      final stream = file.openRead();
      final hash = await md5.bind(stream).first;
      return hash.toString();
    } catch (_) {
      return '';
    }
  }
}
