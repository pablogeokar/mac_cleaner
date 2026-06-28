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
  final double overallProgress;
  final Map<ScanCategoryType, double> categoryProgresses;

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
    required this.overallProgress,
    required this.categoryProgresses,
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
    double? overallProgress,
    Map<ScanCategoryType, double>? categoryProgresses,
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
      overallProgress: overallProgress ?? this.overallProgress,
      categoryProgresses: categoryProgresses ?? this.categoryProgresses,
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
      overallProgress: 0.0,
      categoryProgresses: {for (var type in ScanCategoryType.values) type: 0.0},
    );
  }

  List<ScanCategory> _initializeCategories() {
    return [
      const ScanCategory(
        type: ScanCategoryType.systemCache,
        displayName: 'Cache do Sistema',
        description:
            'Arquivos temporários criados pelo macOS e aplicativos do sistema.',
        icon: Icons.cached,
        targetPaths: ScanPaths.systemCachePaths,
      ),
      const ScanCategory(
        type: ScanCategoryType.systemLogs,
        displayName: 'Logs do Sistema',
        description:
            'Logs de erros e relatórios de diagnósticos gerados pelo sistema.',
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
            'Pastas DerivedData, simuladores, caches do npm/pip/gradle/brew.',
        icon: Icons.developer_mode,
        targetPaths: [], // resolved dynamically
      ),
      const ScanCategory(
        type: ScanCategoryType.largeFiles,
        displayName: 'Arquivos Grandes (>500MB)',
        description:
            'Arquivos que ocupam muito espaço. Deletados apenas sob confirmação.',
        icon: Icons.insert_drive_file,
        targetPaths: ScanPaths.userRoots,
      ),
      const ScanCategory(
        type: ScanCategoryType.duplicates,
        displayName: 'Downloads Duplicados',
        description: 'Arquivos idênticos duplicados nas pastas do usuário.',
        icon: Icons.copy,
        targetPaths: ScanPaths.userRoots,
      ),
      const ScanCategory(
        type: ScanCategoryType.appResiduals,
        displayName: 'Resíduos de Apps',
        description: 'Arquivos de suporte órfãos de aplicativos desinstalados.',
        icon: Icons.cleaning_services,
        targetPaths: ScanPaths.residualSearchPaths,
      ),
      const ScanCategory(
        type: ScanCategoryType.duplicateFonts,
        displayName: 'Fontes Duplicadas',
        description: 'Fontes idênticas instaladas em mais de um diretório.',
        icon: Icons.font_download,
        targetPaths: ScanPaths.fontPaths,
      ),
    ];
  }

  void toggleCategorySelection(ScanCategoryType type) {
    state = state.copyWith(
      categories: state.categories.map((cat) {
        if (cat.type == type) {
          final newSelect = !cat.isSelected;
          // Apply selection to all children items
          final updatedItems = cat.items
              .map((i) => i.copyWith(isSelected: newSelect))
              .toList();
          return cat.copyWith(isSelected: newSelect, items: updatedItems);
        }
        return cat;
      }).toList(),
    );
    _recalculateSelectedSizes();
  }

  void toggleItemSelection(ScanCategoryType categoryType, String itemPath) {
    state = state.copyWith(
      categories: state.categories.map((cat) {
        if (cat.type == categoryType) {
          final updatedItems = cat.items.map((item) {
            if (item.path == itemPath) {
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
      if (cat.isSelected) {
        for (final item in cat.items) {
          if (item.isSelected) {
            selBytes += item.sizeBytes;
            selFiles++;
          }
        }
      }
    }

    state = state.copyWith(
      totalSelectedBytes: selBytes,
      totalSelectedFiles: selFiles,
    );
  }

  void selectAllInCategory(ScanCategoryType type, bool select) {
    state = state.copyWith(
      categories: state.categories.map((cat) {
        if (cat.type == type) {
          final updatedItems = cat.items
              .map((i) => i.copyWith(isSelected: select))
              .toList();
          return cat.copyWith(isSelected: select, items: updatedItems);
        }
        return cat;
      }).toList(),
    );
    _recalculateSelectedSizes();
  }

  /// Starts scanning categories. If `quickScan` is true, only system logs and system caches are scanned.
  Future<void> startScan({bool quickScan = false}) async {
    cancelScan();
    _isCancelled = false;

    // Reset State
    state = ScanState(
      status: ScannerStatus.scanning,
      categories: _initializeCategories(),
      currentProgressLog: 'Inicializando varredura...',
      totalScannedBytes: 0,
      totalScannedFiles: 0,
      totalSelectedBytes: 0,
      totalSelectedFiles: 0,
      totalCleanedBytes: 0,
      totalCleanedFiles: 0,
      overallProgress: 0.0,
      categoryProgresses: {for (var type in ScanCategoryType.values) type: 0.0},
    );

    final targets = state.categories
        .where((cat) {
          if (quickScan) {
            return cat.type == ScanCategoryType.systemCache ||
                cat.type == ScanCategoryType.systemLogs;
          }
          return true;
        })
        .map((c) => c.type)
        .toList();

    // Setup active categories states
    state = state.copyWith(
      categories: state.categories.map((cat) {
        if (targets.contains(cat.type)) {
          return cat.copyWith(isScanning: true);
        }
        return cat;
      }).toList(),
    );

    // Limit concurrency to 3
    final queue = List<ScanCategoryType>.from(targets);
    final activeCompleters = <ScanCategoryType, Completer<void>>{};
    final maxConcurrency = 3;

    Future<void> processNext() async {
      if (queue.isEmpty || _isCancelled) return;
      final currentCatType = queue.removeAt(0);

      final completer = Completer<void>();
      activeCompleters[currentCatType] = completer;

      final settings = ref.read(settingsProvider);
      final stream = ref
          .read(scanSystemUseCaseProvider)
          .call(
            currentCatType,
            largeFileThresholdBytes: settings.largeFileMinSizeBytes,
            tempFileAgeHours: settings.tempFileMinAgeHours,
          );

      final subscription = stream.listen(
        (progress) {
          if (_isCancelled) return;
          _updateProgress(progress);
        },
        onDone: () {
          _finishCategoryScan(currentCatType);
          completer.complete();
        },
        onError: (e) {
          _finishCategoryScan(currentCatType);
          completer.complete();
        },
      );

      _subscriptions.add(subscription);

      await completer.future;
      activeCompleters.remove(currentCatType);

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
        currentProgressLog: 'Varredura finalizada.',
      );
      _recalculateSelectedSizes();
    }
  }

  void _updateProgress(ScanProgress progress) {
    if (state.status != ScannerStatus.scanning) return;

    final updatedProgresses = Map<ScanCategoryType, double>.from(
      state.categoryProgresses,
    )..[progress.category] = progress.progress;

    // Recalculate overall progress
    final scanningCats = state.categories
        .where((c) => c.isScanning || c.fileCount > 0 || c.totalBytes > 0)
        .length;
    double progressSum = 0.0;
    for (final val in updatedProgresses.values) {
      progressSum += val;
    }
    final overall = scanningCats > 0
        ? progressSum / ScanCategoryType.values.length
        : 0.0;

    // Update categories by injecting current scanned items
    final updatedCategories = state.categories.map((cat) {
      if (cat.type == progress.category) {
        return cat.copyWith(
          items: progress.items,
          fileCount: progress.itemsFound,
          totalBytes: progress.bytesFound,
          isScanning: !progress.isComplete,
        );
      }
      return cat;
    }).toList();

    state = state.copyWith(
      categoryProgresses: updatedProgresses,
      categories: updatedCategories,
      overallProgress: min(
        overall,
        0.99,
      ), // Keep under 100% until fully complete
      currentProgressLog: progress.currentPath,
    );
  }

  void _finishCategoryScan(ScanCategoryType type) {
    state = state.copyWith(
      categoryProgresses: Map<ScanCategoryType, double>.from(
        state.categoryProgresses,
      )..[type] = 1.0,
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

    state = state.copyWith(
      status: ScannerStatus.deleting,
      currentProgressLog: 'Removendo arquivos selecionados...',
    );

    final selectedItems = <ScanItem>[];
    for (final cat in state.categories) {
      if (cat.isSelected) {
        selectedItems.addAll(cat.items.where((i) => i.isSelected));
      }
    }

    if (selectedItems.isEmpty) {
      state = state.copyWith(
        status: ScannerStatus.completed,
        currentProgressLog: 'Nenhum item selecionado para limpeza.',
      );
      return false;
    }

    try {
      await ref
          .read(deleteItemsUseCaseProvider)
          .call(selectedItems, permanent: permanent);

      // Recalculate how much space was cleared
      int clearedBytes = 0;
      int clearedFiles = 0;
      for (final item in selectedItems) {
        clearedBytes += item.sizeBytes;
        clearedFiles++;
      }

      // Update disk information gauge on dashboard
      unawaited(ref.read(diskInfoNotifierProvider.notifier).refresh());

      // Update categories by removing deleted files
      final updatedCategories = state.categories.map((cat) {
        final remainingItems = cat.items.where((i) => !i.isSelected).toList();
        final remainingBytes = remainingItems.fold<int>(
          0,
          (sum, i) => sum + i.sizeBytes,
        );
        return cat.copyWith(
          items: remainingItems,
          fileCount: remainingItems.length,
          totalBytes: remainingBytes,
          isSelected: remainingItems.isNotEmpty,
        );
      }).toList();

      state = state.copyWith(
        status: ScannerStatus.finished,
        categories: updatedCategories,
        totalCleanedBytes: clearedBytes,
        totalCleanedFiles: clearedFiles,
        totalSelectedBytes: 0,
        totalSelectedFiles: 0,
        currentProgressLog: 'Limpeza concluída com sucesso!',
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
      overallProgress: 0.0,
      totalScannedBytes: 0,
      totalScannedFiles: 0,
      totalSelectedBytes: 0,
      totalSelectedFiles: 0,
      totalCleanedBytes: 0,
      totalCleanedFiles: 0,
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
          );
        }
        return cat;
      }).toList(),
    );
    _recalculateSelectedSizes();
  }
}
