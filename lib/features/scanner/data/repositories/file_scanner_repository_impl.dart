import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';

import '../../../../core/constants/scan_paths.dart';
import '../../../../core/utils/shell_runner.dart';
import '../../domain/entities/cleanup_result.dart';
import '../../domain/entities/deletion_safety_guard.dart';
import '../../domain/entities/scan_category.dart';
import '../../domain/entities/scan_item.dart';
import '../../domain/entities/scan_progress.dart';
import '../../domain/repositories/file_scanner_repository.dart';

class FileScannerRepositoryImpl implements FileScannerRepository {
  static const _channel = MethodChannel('maccleaner/recycle');

  @override
  Future<CleanupResult> deleteItems(
    List<ScanItem> items, {
    required bool permanent,
    List<String> excludedPaths = const [],
  }) async {
    final removed = <ScanItem>[];
    final skipped = <String, String>{};
    final failed = <String, String>{};

    for (final item in items) {
      final assessment = DeletionSafetyGuard.assess(
        item.path,
        excludedPaths: excludedPaths,
      );
      if (!item.canBeSelected || !assessment.isAllowed) {
        skipped[item.path] = assessment.isAllowed
            ? 'Item classificado como protegido.'
            : assessment.reason;
        continue;
      }

      final path = assessment.normalizedPath;
      try {
        final entityType = await FileSystemEntity.type(
          path,
          followLinks: false,
        );
        if (entityType == FileSystemEntityType.notFound) {
          skipped[item.path] = 'O item não existe mais.';
          continue;
        }
        if (entityType == FileSystemEntityType.link) {
          skipped[item.path] =
              'Links simbólicos são preservados por segurança.';
          continue;
        }
        if (!permanent && _isInsideUserTrash(path)) {
          skipped[item.path] =
              'O item já está na Lixeira; use a remoção permanente para esvaziá-la.';
          continue;
        }

        if (permanent) {
          if (entityType == FileSystemEntityType.directory) {
            await Directory(path).delete(recursive: true);
          } else if (entityType == FileSystemEntityType.file) {
            await File(path).delete();
          } else {
            skipped[item.path] = 'Tipo de item não suportado.';
            continue;
          }
        } else {
          await _channel.invokeMethod('recycle', [path]);
        }
        removed.add(item);
      } on PlatformException catch (error) {
        failed[item.path] = error.message ?? 'Falha ao mover para a Lixeira.';
      } on FileSystemException catch (error) {
        failed[item.path] = error.message;
      } catch (error) {
        failed[item.path] = error.toString();
      }
    }

    return CleanupResult(
      removedItems: removed,
      skippedItems: skipped,
      failedItems: failed,
    );
  }

  @override
  Stream<ScanProgress> scanCategory(
    ScanCategoryType category, {
    int largeFileThresholdBytes = 500 * 1024 * 1024,
    int tempFileAgeHours = 48,
    int systemCacheAgeDays = 7,
    List<String> excludedPaths = const [],
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
              excludedPaths: excludedPaths,
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
              excludedPaths: excludedPaths,
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
              excludedPaths: excludedPaths,
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
              excludedPaths: excludedPaths,
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
              excludedPaths: excludedPaths,
            )) {
              items.add(item);
              totalBytes += item.sizeBytes;
            }
          }
          break;

        case ScanCategoryType.appCache:
          // Only reproducible developer caches are scanned here. Runtime data
          // from Docker, simulators and Android VMs is intentionally excluded.

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
                excludedPaths: excludedPaths,
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

            await for (final item in ShellRunner.listFilesRecursive(
              path,
              excludedPaths: excludedPaths,
            )) {
              if (item.type == ScanItemType.file &&
                  item.sizeBytes >= largeFileThresholdBytes) {
                // Large files should NOT be auto-selected
                items.add(
                  item.copyWith(
                    isSelected: false,
                    isSafeToDelete: true,
                    reason:
                        'Arquivo maior que ${(largeFileThresholdBytes / (1024 * 1024)).round()} MB',
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

            await for (final item in ShellRunner.listFilesRecursive(
              path,
              excludedPaths: excludedPaths,
            )) {
              if (item.type == ScanItemType.file) allCandidates.add(item);
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

            // Full SHA-256 verification avoids selecting files using names or
            // sizes alone.
            final hash = await _getFileHash(item.path);
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
          // Match exact bundle identifiers rather than guessing from app names.
          // If the installed-app inventory cannot be read, fail closed and do
          // not suggest any residual for deletion.
          final installedBundleIds = await _getInstalledBundleIdentifiers();
          if (installedBundleIds.isEmpty) break;

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
                final assessment = DeletionSafetyGuard.assess(
                  entity.path,
                  excludedPaths: excludedPaths,
                );
                if (!assessment.isAllowed) continue;

                final identifier = _candidateBundleIdentifier(entity.path);
                if (identifier == null || _isAppleIdentifier(identifier)) {
                  continue;
                }

                final hasInstalledOwner = installedBundleIds.any(
                  (installed) =>
                      identifier == installed ||
                      identifier.startsWith('$installed.') ||
                      installed.startsWith('$identifier.'),
                );

                if (!hasInstalledOwner) {
                  final stat = await entity.stat();
                  final size = entity is Directory
                      ? await ShellRunner.getDirectorySizeBytes(entity.path)
                      : stat.size;
                  final entityType = await FileSystemEntity.type(
                    entity.path,
                    followLinks: false,
                  );

                  items.add(
                    ScanItem(
                      path: entity.path,
                      fileName: p.basename(entity.path),
                      sizeBytes: size,
                      lastModified: stat.modified,
                      lastAccessed: stat.accessed,
                      type: entityType == FileSystemEntityType.directory
                          ? ScanItemType.directory
                          : entityType == FileSystemEntityType.link
                          ? ScanItemType.symlink
                          : ScanItemType.file,
                      isSelected: false,
                      reason:
                          'Possível resíduo: identificador $identifier sem app correspondente.',
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
              excludedPaths: excludedPaths,
            )) {
              if (item.type != ScanItemType.file) continue;
              final hash = await _getFileHash(item.path);
              if (hash.isNotEmpty) {
                fontFiles.putIfAbsent(hash, () => []).add(item);
              }
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

    final reviewedItems = items
        .map((item) => _applySafetyPolicy(category, item, excludedPaths))
        .toList(growable: false);
    final reviewedBytes = reviewedItems.fold<int>(
      0,
      (total, item) => total + item.sizeBytes,
    );

    yield ScanProgress(
      category: category,
      progress: 1.0,
      currentPath: 'Varredura concluída!',
      itemsFound: reviewedItems.length,
      bytesFound: reviewedBytes,
      isComplete: true,
      items: reviewedItems,
    );
  }

  ScanItem _applySafetyPolicy(
    ScanCategoryType category,
    ScanItem item,
    List<String> excludedPaths,
  ) {
    final assessment = DeletionSafetyGuard.assess(
      item.path,
      excludedPaths: excludedPaths,
    );
    if (!assessment.isAllowed || item.type == ScanItemType.symlink) {
      return item.copyWith(
        isSafeToDelete: false,
        riskLevel: ScanRiskLevel.protected,
        isSelected: false,
        reason: item.type == ScanItemType.symlink
            ? 'Link simbólico preservado por segurança.'
            : assessment.reason,
      );
    }

    final needsReview =
        category == ScanCategoryType.temporaryFiles ||
        category == ScanCategoryType.trash ||
        category == ScanCategoryType.largeFiles ||
        category == ScanCategoryType.duplicates ||
        category == ScanCategoryType.appResiduals ||
        category == ScanCategoryType.duplicateFonts;

    return item.copyWith(
      isSafeToDelete: true,
      riskLevel: needsReview ? ScanRiskLevel.caution : ScanRiskLevel.safe,
      isSelected: needsReview ? false : item.isSelected,
      reason:
          item.reason ??
          (needsReview
              ? 'Requer revisão manual antes da limpeza.'
              : 'Arquivo recriável em uma área de limpeza aprovada.'),
    );
  }

  bool _isInsideUserTrash(String path) {
    final trash = p.normalize(ScanPaths.expandPath('~/.Trash')).toLowerCase();
    final normalized = p.normalize(path).toLowerCase();
    return normalized == trash || p.isWithin(trash, normalized);
  }

  Future<Set<String>> _getInstalledBundleIdentifiers() async {
    final identifiers = <String>{};
    for (final root in [
      '/Applications',
      ScanPaths.expandPath('~/Applications'),
    ]) {
      final directory = Directory(root);
      if (!await directory.exists()) continue;

      try {
        await for (final entity in directory.list(recursive: false)) {
          if (entity is! Directory || !entity.path.endsWith('.app')) continue;
          final infoPlist = p.join(entity.path, 'Contents', 'Info.plist');
          if (!await File(infoPlist).exists()) continue;
          final result = await ShellRunner.run('plutil', [
            '-extract',
            'CFBundleIdentifier',
            'raw',
            infoPlist,
          ], timeout: const Duration(seconds: 5));
          if (result.exitCode == 0) {
            final identifier = result.stdout.toString().trim().toLowerCase();
            if (identifier.isNotEmpty) identifiers.add(identifier);
          }
        }
      } catch (_) {
        // Partial inventories are acceptable; every result remains opt-in.
      }
    }
    return identifiers;
  }

  String? _candidateBundleIdentifier(String path) {
    var name = p.basename(path).toLowerCase();
    for (final suffix in ['.plist', '.appex', '.bundle']) {
      if (name.endsWith(suffix)) {
        name = name.substring(0, name.length - suffix.length);
      }
    }
    final pattern = RegExp(r'^[a-z0-9][a-z0-9-]*(\.[a-z0-9][a-z0-9_-]*)+$');
    return pattern.hasMatch(name) ? name : null;
  }

  bool _isAppleIdentifier(String identifier) {
    return identifier.startsWith('com.apple.') ||
        identifier.startsWith('group.com.apple.') ||
        identifier.startsWith('systemgroup.com.apple.') ||
        identifier.startsWith('apple.');
  }

  Future<String> _getFileHash(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return '';
    try {
      final stream = file.openRead();
      final hash = await sha256.bind(stream).first;
      return hash.toString();
    } catch (_) {
      return '';
    }
  }
}
