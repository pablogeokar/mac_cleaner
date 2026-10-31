import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/constants/scan_paths.dart';
import '../../../dashboard/presentation/providers/disk_info_provider.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../data/repositories/file_scanner_repository_impl.dart';
import '../../domain/entities/scan_category.dart';
import '../../domain/entities/scan_item.dart';
import '../../domain/entities/scan_progress.dart';
import '../../domain/repositories/file_scanner_repository.dart';
import '../../domain/use_cases/delete_items_use_case.dart';
import '../../domain/use_cases/scan_system_use_case.dart';

part 'scan_provider.g.dart';

enum ScannerStatus { idle, scanning, completed, deleting, finished }

class ScanState {
  final ScannerStatus status;
  final List<ScanCategory> categories;
  final String currentProgressLog;
  final int totalScannedBytes;
  final int totalScannedFiles;
  final int totalSelectedBytes;
  final int totalSelectedFiles;
  final int totalCleanedBytes;
  final int totalCleanedFiles;
  final int totalSkippedFiles;
  final int totalFailedFiles;
  final Map<String, String> cleanupIssues;
  final Set<String> permissionDeniedPaths;
  final double overallProgress;
  final Map<ScanCategoryType, double> categoryProgresses;
  final List<ScanCategoryType> scanTargets;
  final Map<ScanCategoryType, String> scanErrors;

  const ScanState({
    required this.status,
    required this.categories,
    required this.currentProgressLog,
    required this.totalScannedBytes,
    required this.totalScannedFiles,
    required this.totalSelectedBytes,
    required this.totalSelectedFiles,
    required this.totalCleanedBytes,
    required this.totalCleanedFiles,
    required this.totalSkippedFiles,
    required this.totalFailedFiles,
    required this.cleanupIssues,
    required this.permissionDeniedPaths,
    required this.overallProgress,
    required this.categoryProgresses,
    required this.scanTargets,
    required this.scanErrors,
  });

  ScanState copyWith({
    ScannerStatus? status,
    List<ScanCategory>? categories,
    String? currentProgressLog,
    int? totalScannedBytes,
    int? totalScannedFiles,
    int? totalSelectedBytes,
    int? totalSelectedFiles,
    int? totalCleanedBytes,
    int? totalCleanedFiles,
    int? totalSkippedFiles,
    int? totalFailedFiles,
    Map<String, String>? cleanupIssues,
    Set<String>? permissionDeniedPaths,
    double? overallProgress,
    Map<ScanCategoryType, double>? categoryProgresses,
    List<ScanCategoryType>? scanTargets,
    Map<ScanCategoryType, String>? scanErrors,
  }) {
    return ScanState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      currentProgressLog: currentProgressLog ?? this.currentProgressLog,
      totalScannedBytes: totalScannedBytes ?? this.totalScannedBytes,
      totalScannedFiles: totalScannedFiles ?? this.totalScannedFiles,
      totalSelectedBytes: totalSelectedBytes ?? this.totalSelectedBytes,
      totalSelectedFiles: totalSelectedFiles ?? this.totalSelectedFiles,
      totalCleanedBytes: totalCleanedBytes ?? this.totalCleanedBytes,
      totalCleanedFiles: totalCleanedFiles ?? this.totalCleanedFiles,
      totalSkippedFiles: totalSkippedFiles ?? this.totalSkippedFiles,
      totalFailedFiles: totalFailedFiles ?? this.totalFailedFiles,
      cleanupIssues: cleanupIssues ?? this.cleanupIssues,
      permissionDeniedPaths:
          permissionDeniedPaths ?? this.permissionDeniedPaths,
      overallProgress: overallProgress ?? this.overallProgress,
      categoryProgresses: categoryProgresses ?? this.categoryProgresses,
      scanTargets: scanTargets ?? this.scanTargets,
      scanErrors: scanErrors ?? this.scanErrors,
    );
  }
}

@riverpod
FileScannerRepository fileScannerRepository(Ref ref) {
  return FileScannerRepositoryImpl();
}

@riverpod
ScanSystemUseCase scanSystemUseCase(Ref ref) {
  return ScanSystemUseCase(ref.watch(fileScannerRepositoryProvider));
}

@riverpod
DeleteItemsUseCase deleteItemsUseCase(Ref ref) {
  return DeleteItemsUseCase(ref.watch(fileScannerRepositoryProvider));
}

@riverpod
class ScannerNotifier extends _$ScannerNotifier {
  final List<StreamSubscription> _subscriptions = [];
  bool _isCancelled = false;

  @override
  ScanState build() {
    // Clean up subscriptions when provider is disposed
    ref.onDispose(() {
      cancelScan();
    });

    return ScanState(
      status: ScannerStatus.idle,
      categories: _initializeCategories(),
      currentProgressLog: 'Pronto para escanear.',
      totalScannedBytes: 0,
      totalScannedFiles: 0,
      totalSelectedBytes: 0,
      totalSelectedFiles: 0,
      totalCleanedBytes: 0,
      totalCleanedFiles: 0,
      totalSkippedFiles: 0,
      totalFailedFiles: 0,
      cleanupIssues: const {},
      permissionDeniedPaths: const {},
      overallProgress: 0.0,
      categoryProgresses: {for (var type in ScanCategoryType.values) type: 0.0},
      scanTargets: const [],
      scanErrors: const {},
    );
  }

  List<ScanCategory> _initializeCategories() {
    return [
      const ScanCategory(
        type: ScanCategoryType.systemCache,
        displayName: 'Cache do Sistema',
        description:
            'Caches antigos da biblioteca do usuário, que podem ser recriados.',
        icon: Icons.cached,
        targetPaths: ScanPaths.systemCachePaths,
      ),
      const ScanCategory(
        type: ScanCategoryType.systemLogs,
        displayName: 'Logs do Sistema',
        description: 'Logs antigos do usuário e dos aplicativos instalados.',
        icon: Icons.description,
        targetPaths: ScanPaths.systemLogsPaths,
      ),
      const ScanCategory(
        type: ScanCategoryType.temporaryFiles,
        displayName: 'Arquivos Temporários',
        description:
            'Arquivos de cache temporário em /tmp e downloads inacabados.',
        icon: Icons.delete_outline,
        targetPaths: ScanPaths.temporaryPaths,
      ),
      const ScanCategory(
        type: ScanCategoryType.trash,
        displayName: 'Lixeira do Usuário',
        description: 'Arquivos que foram descartados e residem na lixeira.',
        icon: Icons.delete,
        targetPaths: ScanPaths.trashPaths,
      ),
      const ScanCategory(
        type: ScanCategoryType.appCache,
        displayName: 'Caches de Desenvolvedor',
        description:
            'Caches recriáveis de Xcode, npm, pip, Gradle, Maven e Homebrew.',
        icon: Icons.developer_mode,
        targetPaths: [], // resolved dynamically
      ),
      const ScanCategory(
        type: ScanCategoryType.largeFiles,
        displayName: 'Arquivos Grandes',
        description:
            'Arquivos que ocupam muito espaço. Deletados apenas sob confirmação.',
        icon: Icons.insert_drive_file,
        targetPaths: ScanPaths.userRoots,
        isSelected: false,
      ),
      const ScanCategory(
        type: ScanCategoryType.duplicates,
        displayName: 'Downloads Duplicados',
        description: 'Arquivos idênticos duplicados nas pastas do usuário.',
        icon: Icons.copy,
        targetPaths: ScanPaths.userRoots,
        isSelected: false,
      ),
      const ScanCategory(
        type: ScanCategoryType.appResiduals,
        displayName: 'Resíduos de Apps',
        description:
            'Arquivos de suporte e contêineres de apps possivelmente desinstalados.',
        icon: Icons.cleaning_services,
        targetPaths: ScanPaths.residualSearchPaths,
        isSelected: false,
      ),
      const ScanCategory(
        type: ScanCategoryType.duplicateFonts,
        displayName: 'Fontes Duplicadas',
        description: 'Fontes idênticas instaladas em mais de um diretório.',
        icon: Icons.font_download,
        targetPaths: ScanPaths.fontPaths,
        isSelected: false,
      ),
    ];
  }

  void toggleCategorySelection(ScanCategoryType type) {
    state = state.copyWith(
      categories: state.categories.map((cat) {
        if (cat.type == type) {
          final newSelect = !cat.isSelected;
          final updatedItems = cat.items
              .map(
                (item) => item.copyWith(
                  isSelected:
                      newSelect &&
                      item.canBeSelected &&
                      item.riskLevel == ScanRiskLevel.safe,
                ),
              )
              .toList();
          return cat.copyWith(isSelected: newSelect, items: updatedItems);
        }
        return cat;
      }).toList(),
    );
    _recalculateSelectedSizes();
  }

  void toggleItemSelection(ScanCategoryType categoryType, String itemPath) {
    if (state.status == ScannerStatus.deleting) return;
    state = state.copyWith(
      categories: state.categories.map((cat) {
        if (cat.type == categoryType) {
          final updatedItems = cat.items.map((item) {
            if (item.path == itemPath && item.canBeSelected) {
              return item.copyWith(isSelected: !item.isSelected);
            }
            return item;
          }).toList();

          final anySelected = updatedItems.any((i) => i.isSelected);
          return cat.copyWith(items: updatedItems, isSelected: anySelected);
        }
        return cat;
      }).toList(),
    );
    _recalculateSelectedSizes();
  }

  void _recalculateSelectedSizes() {
    int selBytes = 0;
    int selFiles = 0;

    for (final cat in state.categories) {
      for (final item in cat.items) {
        if (item.isSelected && item.canBeSelected) {
          selBytes += item.sizeBytes;
          selFiles++;
        }
      }
    }

    state = state.copyWith(
      totalSelectedBytes: selBytes,
      totalSelectedFiles: selFiles,
    );
  }

  void selectAllInCategory(ScanCategoryType type, bool select) {
    if (state.status == ScannerStatus.deleting) return;
    state = state.copyWith(
      categories: state.categories.map((cat) {
        if (cat.type == type) {
          final updatedItems = cat.items
              .map(
                (item) =>
                    item.copyWith(isSelected: select && item.canBeSelected),
              )
              .toList();
          return cat.copyWith(
            isSelected: updatedItems.any((item) => item.isSelected),
            items: updatedItems,
          );
        }
        return cat;
      }).toList(),
    );
    _recalculateSelectedSizes();
  }

  /// Starts scanning categories. If `quickScan` is true, only system logs and system caches are scanned.
  Future<bool> startScan({bool quickScan = false}) async {
    cancelScan();
    _isCancelled = false;

    final previousCategories = state.categories;
    final selectedTypes = {
      for (final category in previousCategories)
        if (category.isSelected) category.type,
    };
    final targets = previousCategories
        .where((cat) {
          if (!selectedTypes.contains(cat.type)) return false;
          if (quickScan) {
            return cat.type == ScanCategoryType.systemCache ||
                cat.type == ScanCategoryType.systemLogs;
          }
          return true;
        })
        .map((c) => c.type)
        .toList();

    if (targets.isEmpty) {
      state = state.copyWith(
        currentProgressLog: quickScan
            ? 'Selecione Cache do Sistema ou Logs do Sistema para executar a varredura rápida.'
            : 'Selecione pelo menos uma categoria para iniciar a varredura.',
      );
      return false;
    }
    final initialCategories = _initializeCategories().map((category) {
      final isSelected = selectedTypes.contains(category.type);
      return category.copyWith(isSelected: isSelected);
    }).toList();

    // Reset State
    state = ScanState(
      status: ScannerStatus.scanning,
      categories: initialCategories,
      currentProgressLog: 'Inicializando varredura...',
      totalScannedBytes: 0,
      totalScannedFiles: 0,
      totalSelectedBytes: 0,
      totalSelectedFiles: 0,
      totalCleanedBytes: 0,
      totalCleanedFiles: 0,
      totalSkippedFiles: 0,
      totalFailedFiles: 0,
      cleanupIssues: const {},
      permissionDeniedPaths: const {},
      overallProgress: 0.0,
      categoryProgresses: {for (var type in ScanCategoryType.values) type: 0.0},
      scanTargets: targets,
      scanErrors: const {},
    );

    // Limit concurrency to 3
    final queue = List<ScanCategoryType>.from(targets);
    final maxConcurrency = 3;

    Future<void> processNext() async {
      if (queue.isEmpty || _isCancelled) return;
      final currentCatType = queue.removeAt(0);

      final completer = Completer<void>();

      state = state.copyWith(
        categories: state.categories.map((cat) {
          return cat.type == currentCatType
              ? cat.copyWith(isScanning: true)
              : cat;
        }).toList(),
      );

      final settings = ref.read(settingsProvider);
      final stream = ref
          .read(scanSystemUseCaseProvider)
          .call(
            currentCatType,
            largeFileThresholdBytes: settings.largeFileMinSizeBytes,
            tempFileAgeHours: settings.tempFileMinAgeHours,
            systemCacheAgeDays: settings.systemCacheMinAgeDays,
            excludedPaths: settings.excludedPaths,
          );

      final subscription = stream.listen(
        (progress) {
          if (_isCancelled) return;
          _updateProgress(progress);
        },
        onDone: () {
          if (!completer.isCompleted) {
            if (!_isCancelled) _finishCategoryScan(currentCatType);
            completer.complete();
          }
        },
        onError: (e) {
          if (!completer.isCompleted) {
            if (!_isCancelled) {
              _finishCategoryScan(currentCatType, error: e.toString());
            }
            completer.complete();
          }
        },
        cancelOnError: true,
      );

      _subscriptions.add(subscription);

      await completer.future;

      if (state.status == ScannerStatus.scanning && !_isCancelled) {
        await processNext();
      }
    }

    final workers = <Future>[];
    final initialCount = min(maxConcurrency, queue.length);
    for (int i = 0; i < initialCount; i++) {
      workers.add(processNext());
    }

    await Future.wait(workers);

    if (!_isCancelled) {
      state = state.copyWith(
        status: ScannerStatus.completed,
        overallProgress: 1.0,
        currentProgressLog: state.scanErrors.isEmpty
            ? 'Varredura finalizada.'
            : 'Varredura finalizada com falhas em ${state.scanErrors.length} categoria(s).',
      );
      _recalculateSelectedSizes();
      return true;
    }

    return false;
  }

  void _updateProgress(ScanProgress progress) {
    if (state.status != ScannerStatus.scanning) return;

    final updatedProgresses = Map<ScanCategoryType, double>.from(
      state.categoryProgresses,
    )..[progress.category] = min(progress.progress, 0.99);

    // Update categories by injecting current scanned items
    final updatedCategories = state.categories.map((cat) {
      if (cat.type == progress.category) {
        return cat.copyWith(
          items: progress.items,
          fileCount: progress.itemsFound,
          totalBytes: progress.bytesFound,
          isScanning: true,
          isSelected: progress.isComplete
              ? progress.items.any((item) => item.isSelected)
              : cat.isSelected,
        );
      }
      return cat;
    }).toList();
    final totalFiles = updatedCategories.fold<int>(
      0,
      (total, category) => total + category.fileCount,
    );
    final totalBytes = updatedCategories.fold<int>(
      0,
      (total, category) => total + category.totalBytes,
    );

    state = state.copyWith(
      categoryProgresses: updatedProgresses,
      categories: updatedCategories,
      totalScannedFiles: totalFiles,
      totalScannedBytes: totalBytes,
      currentProgressLog: progress.currentPath,
    );
  }

  void _finishCategoryScan(ScanCategoryType type, {String? error}) {
    final updatedProgresses = Map<ScanCategoryType, double>.from(
      state.categoryProgresses,
    );
    final updatedErrors = Map<ScanCategoryType, String>.from(state.scanErrors);
    if (error == null) {
      updatedProgresses[type] = 1.0;
    } else {
      updatedErrors[type] = error;
    }
    final processedCount = state.scanTargets
        .where(
          (target) =>
              updatedProgresses[target] == 1.0 ||
              updatedErrors.containsKey(target),
        )
        .length;
    state = state.copyWith(
      categoryProgresses: updatedProgresses,
      scanErrors: updatedErrors,
      overallProgress: state.scanTargets.isEmpty
          ? 0.0
          : min(processedCount / state.scanTargets.length, 0.99),
      currentProgressLog: error == null
          ? state.currentProgressLog
          : 'Falha ao varrer ${state.categories.firstWhere((cat) => cat.type == type).displayName}: $error',
      categories: state.categories.map((cat) {
        if (cat.type == type) {
          return cat.copyWith(isScanning: false);
        }
        return cat;
      }).toList(),
    );
  }

  /// Cancels any active scan streams.
  void cancelScan() {
    _isCancelled = true;
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    if (state.status == ScannerStatus.scanning) {
      state = state.copyWith(
        status: ScannerStatus.idle,
        overallProgress: 0.0,
        currentProgressLog: 'Varredura cancelada pelo usuário.',
      );
    }
  }

  /// Performs cleaning of selected items.
  Future<bool> startCleanup({required bool permanent}) async {
    if (state.status != ScannerStatus.completed) {
      state = state.copyWith(
        currentProgressLog:
            'A limpeza só pode ser iniciada após uma varredura concluída.',
      );
      return false;
    }

    final settings = ref.read(settingsProvider);
    if (permanent && !settings.allowPermanentDeletion) {
      state = state.copyWith(
        currentProgressLog:
            'A exclusão permanente está bloqueada nas configurações.',
      );
      return false;
    }

    state = state.copyWith(
      status: ScannerStatus.deleting,
      currentProgressLog: 'Removendo arquivos selecionados...',
    );

    final selectedItems = <ScanItem>[];
    for (final cat in state.categories) {
      selectedItems.addAll(
        cat.items.where((item) => item.isSelected && item.canBeSelected),
      );
    }

    if (selectedItems.isEmpty) {
      state = state.copyWith(
        status: ScannerStatus.completed,
        currentProgressLog: 'Nenhum item selecionado para limpeza.',
      );
      return false;
    }

    try {
      final result = await ref
          .read(deleteItemsUseCaseProvider)
          .call(
            selectedItems,
            permanent: permanent,
            excludedPaths: settings.excludedPaths,
          );

      // Update disk information gauge on dashboard
      unawaited(ref.read(diskInfoNotifierProvider.notifier).refresh());

      final removedPaths = result.removedItems.map((item) => item.path).toSet();
      final updatedCategories = state.categories.map((cat) {
        final remainingItems = cat.items
            .where((item) => !removedPaths.contains(item.path))
            .map((item) => item.copyWith(isSelected: false))
            .toList();
        final remainingBytes = remainingItems.fold<int>(
          0,
          (sum, i) => sum + i.sizeBytes,
        );
        return cat.copyWith(
          items: remainingItems,
          fileCount: remainingItems.length,
          totalBytes: remainingBytes,
          isSelected: remainingItems.any((item) => item.isSelected),
        );
      }).toList();

      state = state.copyWith(
        status: ScannerStatus.finished,
        categories: updatedCategories,
        totalCleanedBytes: result.removedBytes,
        totalCleanedFiles: result.removedCount,
        totalSkippedFiles: result.skippedCount,
        totalFailedFiles: result.failedCount,
        cleanupIssues: {...result.skippedItems, ...result.failedItems},
        permissionDeniedPaths: result.permissionDeniedPaths,
        totalSelectedBytes: 0,
        totalSelectedFiles: 0,
        currentProgressLog: result.failedCount == 0 && result.skippedCount == 0
            ? 'Limpeza concluída com sucesso!'
            : 'Limpeza concluída com itens preservados ou com falha.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: ScannerStatus.completed,
        currentProgressLog: 'Erro durante a remoção: $e',
      );
      return false;
    }
  }

  void resetToDashboard() {
    state = state.copyWith(
      status: ScannerStatus.idle,
      categories: _initializeCategories(),
      overallProgress: 0.0,
      scanTargets: const [],
      scanErrors: const {},
      totalScannedBytes: 0,
      totalScannedFiles: 0,
      totalSelectedBytes: 0,
      totalSelectedFiles: 0,
      totalCleanedBytes: 0,
      totalCleanedFiles: 0,
      totalSkippedFiles: 0,
      totalFailedFiles: 0,
      cleanupIssues: const {},
      permissionDeniedPaths: const {},
      currentProgressLog: 'Pronto para escanear.',
    );
  }

  // Internal helper to inject scanned items into category state
  void updateCategoryItems(ScanCategoryType type, List<ScanItem> items) {
    final size = items.fold<int>(0, (sum, i) => sum + i.sizeBytes);
    state = state.copyWith(
      categories: state.categories.map((cat) {
        if (cat.type == type) {
          return cat.copyWith(
            items: items,
            fileCount: items.length,
            totalBytes: size,
            isScanning: false,
            isSelected: items.any((item) => item.isSelected),
          );
        }
        return cat;
      }).toList(),
    );
    _recalculateSelectedSizes();
  }
}
