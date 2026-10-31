import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/utils/file_size_formatter.dart';
import '../../dashboard/presentation/widgets/macos_window_shell.dart';

import '../../scanner/domain/entities/scan_item.dart';
import '../../scanner/presentation/providers/scan_provider.dart';
import '../../settings/presentation/providers/settings_provider.dart';
import 'widgets/file_item_row.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  String _searchQuery = '';
  String _sortBy = 'size_desc'; // size_desc, size_asc, name, date_desc
  String _riskFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(scannerNotifierProvider);

    // Watch status changes to auto-navigate to report screen
    ref.listen(scannerNotifierProvider, (previous, next) {
      if (previous?.status != ScannerStatus.deleting &&
          next.status == ScannerStatus.deleting) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Movendo arquivos selecionados para a Lixeira...'),
            duration: Duration(seconds: 4),
          ),
        );
      }

      if (next.status == ScannerStatus.finished) {
        context.go('/report');
      }

      final message = next.currentProgressLog;
      if (previous?.currentProgressLog != message &&
          next.status == ScannerStatus.completed &&
          message.startsWith('Erro durante a remoção')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    });

    final totalFoundFormatted = FileSizeFormatter.format(
      scanState.categories.fold<int>(0, (sum, cat) => sum + cat.totalBytes),
    );
    final isDeleting = scanState.status == ScannerStatus.deleting;
    final allItems = scanState.categories.expand((category) => category.items);
    final safeCount = allItems
        .where((item) => item.riskLevel == ScanRiskLevel.safe)
        .length;
    final cautionCount = allItems
        .where((item) => item.riskLevel == ScanRiskLevel.caution)
        .length;
    final protectedCount = allItems
        .where((item) => item.riskLevel == ScanRiskLevel.protected)
        .length;

    return MacosWindowShell(
      currentRoute: '/results',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Screen Title & Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$totalFoundFormatted Encontrados',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Selecione os itens que deseja remover com segurança.',
                      style: TextStyle(fontSize: 11, color: Colors.white38),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () => _exportScanReport(context, scanState),
                  icon: const Icon(Icons.ios_share_outlined, size: 16),
                  label: const Text('Exportar relatório'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _RiskSummaryChip(
                  label: '$safeCount recomendados',
                  color: const Color(0xFF68D391),
                  icon: Icons.verified_user_outlined,
                ),
                _RiskSummaryChip(
                  label: '$cautionCount para revisar',
                  color: Colors.orangeAccent,
                  icon: Icons.visibility_outlined,
                ),
                _RiskSummaryChip(
                  label: '$protectedCount protegidos',
                  color: Colors.redAccent,
                  icon: Icons.lock_outline,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Filter and Search controls
            Row(
              children: [
                // Search Input
                Expanded(
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search,
                          size: 16,
                          color: Colors.white38,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value.toLowerCase();
                              });
                            },
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Buscar por nome, caminho ou motivo...',
                              hintStyle: TextStyle(
                                fontSize: 12,
                                color: Colors.white24,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _riskFilter,
                      dropdownColor: const Color(0xFF1E1E22),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _riskFilter = value);
                        }
                      },
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('Todos os riscos'),
                        ),
                        DropdownMenuItem(
                          value: 'safe',
                          child: Text('Recomendados'),
                        ),
                        DropdownMenuItem(
                          value: 'caution',
                          child: Text('Revisar'),
                        ),
                        DropdownMenuItem(
                          value: 'protected',
                          child: Text('Protegidos'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Sort Dropdown
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sortBy,
                      dropdownColor: const Color(0xFF1E1E22),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _sortBy = value;
                          });
                        }
                      },
                      items: const [
                        DropdownMenuItem(
                          value: 'size_desc',
                          child: Text('Tamanho (Maior primeiro)'),
                        ),
                        DropdownMenuItem(
                          value: 'size_asc',
                          child: Text('Tamanho (Menor primeiro)'),
                        ),
                        DropdownMenuItem(
                          value: 'name',
                          child: Text('Nome (A-Z)'),
                        ),
                        DropdownMenuItem(
                          value: 'date_desc',
                          child: Text('Data (Mais recentes)'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Categories Expandable List
            Expanded(
              child: ListView.builder(
                itemCount: scanState.categories.length,
                itemBuilder: (context, index) {
                  final cat = scanState.categories[index];
                  final filteredItems = _getFilteredAndSortedItems(cat.items);
                  final selectableItems = cat.items.where(
                    (item) => item.canBeSelected,
                  );
                  final selectableCount = selectableItems.length;
                  final selectedCount = selectableItems
                      .where((item) => item.isSelected)
                      .length;
                  final protectedCount = cat.items.length - selectableCount;
                  final bool? categorySelection = selectedCount == 0
                      ? false
                      : selectedCount == selectableCount
                      ? true
                      : null;

                  if (cat.items.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  final catSizeFormatted = FileSizeFormatter.format(
                    cat.totalBytes,
                  );

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF242428).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                    child: ExpansionTile(
                      shape: const Border(),
                      iconColor: Theme.of(context).primaryColor,
                      collapsedIconColor: Colors.white30,
                      leading: Icon(cat.icon, color: Colors.white70, size: 18),
                      title: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cat.displayName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${cat.fileCount} itens localizados',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            catSizeFormatted,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Row(
                        children: [
                          Checkbox(
                            value: categorySelection,
                            tristate: true,
                            activeColor: Theme.of(context).primaryColor,
                            checkColor: Colors.black,
                            onChanged: selectableCount == 0 || isDeleting
                                ? null
                                : (_) => ref
                                      .read(scannerNotifierProvider.notifier)
                                      .selectAllInCategory(
                                        cat.type,
                                        selectedCount < selectableCount,
                                      ),
                          ),
                          Text(
                            '$selectedCount de $selectableCount selecionáveis'
                            '${protectedCount > 0 ? ' • $protectedCount protegidos' : ''}',
                            style: TextStyle(
                              fontSize: 10,
                              color: selectableCount > 0
                                  ? Colors.white54
                                  : Colors.white38,
                            ),
                          ),
                        ],
                      ),
                      children: [
                        const Divider(),
                        if (filteredItems.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Nenhum item corresponde ao filtro.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white24,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredItems.length,
                            itemBuilder: (context, itemIdx) {
                              final item = filteredItems[itemIdx];
                              return FileItemRow(
                                item: item,
                                categoryType: cat.type,
                              );
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Bottom Actions Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF242428).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selecionados para Limpeza',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.4),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${FileSizeFormatter.format(scanState.totalSelectedBytes)} (${scanState.totalSelectedFiles} arquivos)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Cancel Button
                      OutlinedButton(
                        onPressed: isDeleting
                            ? null
                            : () {
                                ref
                                    .read(scannerNotifierProvider.notifier)
                                    .resetToDashboard();
                                context.go('/');
                              },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Descartar',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Clean Button
                      ElevatedButton(
                        onPressed:
                            scanState.totalSelectedFiles > 0 && !isDeleting
                            ? () => _showCleanupConfirmation(context)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: isDeleting
                            ? const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Movendo...',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                            : const Text(
                                'Limpar Selecionados',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<ScanItem> _getFilteredAndSortedItems(List<ScanItem> items) {
    // 1. Filter by Search Query
    var list = List<ScanItem>.from(items);
    if (_searchQuery.isNotEmpty) {
      list = list
          .where(
            (item) =>
                item.fileName.toLowerCase().contains(_searchQuery) ||
                item.path.toLowerCase().contains(_searchQuery) ||
                (item.reason?.toLowerCase().contains(_searchQuery) ?? false),
          )
          .toList();
    }

    if (_riskFilter != 'all') {
      list = list.where((item) => item.riskLevel.name == _riskFilter).toList();
    }

    // 2. Sort
    switch (_sortBy) {
      case 'size_desc':
        list.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
        break;
      case 'size_asc':
        list.sort((a, b) => a.sizeBytes.compareTo(b.sizeBytes));
        break;
      case 'name':
        list.sort(
          (a, b) =>
              a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase()),
        );
        break;
      case 'date_desc':
        list.sort((a, b) => b.lastModified.compareTo(a.lastModified));
        break;
    }
    return list;
  }

  Future<void> _exportScanReport(
    BuildContext context,
    ScanState scanState,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      await tempDir.create(recursive: true);
      final file = File('${tempDir.path}/maccleaner-scan-log-$timestamp.csv');
      final sink = file.openWrite();

      sink.writeln('Relatório de varredura do MacCleaner');
      sink.writeln('Generated at,${_csv(DateTime.now().toIso8601String())}');
      sink.writeln(
        'Total bytes,${scanState.categories.fold<int>(0, (sum, cat) => sum + cat.totalBytes)}',
      );
      sink.writeln(
        'Total files,${scanState.categories.fold<int>(0, (sum, cat) => sum + cat.fileCount)}',
      );
      sink.writeln();

      sink.writeln('Category summary');
      sink.writeln('category,type,fileCount,totalBytes,isSelected');
      for (final category in scanState.categories) {
        sink.writeln(
          [
            category.displayName,
            category.type.name,
            category.fileCount.toString(),
            category.totalBytes.toString(),
            category.isSelected.toString(),
          ].map(_csv).join(','),
        );
      }
      sink.writeln();

      sink.writeln('Items');
      sink.writeln(
        'category,categoryType,path,fileName,sizeBytes,type,riskLevel,lastModified,lastAccessed,isSafeToDelete,isSelected,reason',
      );
      for (final category in scanState.categories) {
        final items = List<ScanItem>.from(category.items)
          ..sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
        for (final item in items) {
          sink.writeln(
            [
              category.displayName,
              category.type.name,
              item.path,
              item.fileName,
              item.sizeBytes.toString(),
              item.type.name,
              item.riskLevel.name,
              item.lastModified.toIso8601String(),
              item.lastAccessed.toIso8601String(),
              item.isSafeToDelete.toString(),
              item.isSelected.toString(),
              item.reason ?? '',
            ].map(_csv).join(','),
          );
        }
      }

      await sink.flush();
      await sink.close();

      messenger.showSnackBar(
        SnackBar(
          content: Text('Log gerado em: ${file.path}'),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Abrir no Finder',
            onPressed: () => _revealInFinder(file.path),
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erro ao gerar log: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  String _csv(String value) {
    final formulaSafe = RegExp(r'^[=+\-@]').hasMatch(value) ? "'$value" : value;
    final escaped = formulaSafe.replaceAll('"', '""');
    return '"$escaped"';
  }

  Future<void> _revealInFinder(String path) async {
    await Process.run('open', ['-R', path]);
  }

  void _showCleanupConfirmation(BuildContext context) {
    final scanState = ref.read(scannerNotifierProvider);
    final selectedBytes = scanState.totalSelectedBytes;
    final selectedFiles = scanState.totalSelectedFiles;
    final sizeFormatted = FileSizeFormatter.format(selectedBytes);

    bool isPermanent = false;
    String confirmationText = '';
    final settings = ref.read(settingsProvider);
    final selectedItems = scanState.categories
        .expand((category) => category.items)
        .where((item) => item.isSelected)
        .toList();
    final reviewCount = selectedItems
        .where((item) => item.riskLevel == ScanRiskLevel.caution)
        .length;
    final trashCount = selectedItems
        .where((item) => item.path.contains('/.Trash/'))
        .length;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                  SizedBox(width: 10),
                  Text(
                    'Confirmar Limpeza',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Você está prestes a limpar $selectedFiles arquivos ($sizeFormatted).',
                    style: const TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (reviewCount > 0)
                    _DialogNotice(
                      text:
                          '$reviewCount item(ns) exigem revisão. Confira a lista antes de continuar.',
                      color: Colors.orangeAccent,
                      icon: Icons.visibility_outlined,
                    ),
                  if (trashCount > 0 && !isPermanent) ...[
                    const SizedBox(height: 8),
                    _DialogNotice(
                      text:
                          '$trashCount item(ns) já estão na Lixeira e serão preservados neste modo.',
                      color: Colors.orangeAccent,
                      icon: Icons.info_outline,
                    ),
                  ],
                  if (settings.allowPermanentDeletion)
                    CheckboxListTile(
                      value: isPermanent,
                      activeColor: Theme.of(context).primaryColor,
                      checkColor: Colors.black,
                      title: const Text(
                        'Deletar permanentemente (ignorar Lixeira)',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setDialogState(() {
                          isPermanent = val ?? false;
                          confirmationText = '';
                        });
                      },
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'A exclusão permanente está bloqueada nas configurações.',
                        style: TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ),
                  if (isPermanent) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 14,
                            color: Colors.redAccent,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Atenção: A remoção permanente é irreversível!',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      autofocus: true,
                      onChanged: (value) {
                        setDialogState(() => confirmationText = value);
                      },
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: const InputDecoration(
                        labelText: 'Digite APAGAR para confirmar',
                        labelStyle: TextStyle(color: Colors.white38),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                ElevatedButton(
                  onPressed: isPermanent && confirmationText != 'APAGAR'
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                          _startCleanup(context, permanent: isPermanent);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPermanent
                        ? Colors.redAccent
                        : Theme.of(context).primaryColor,
                    foregroundColor: Colors.black,
                  ),
                  child: Text(
                    isPermanent ? 'Deletar' : 'Mover para Lixeira',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _startCleanup(
    BuildContext context, {
    required bool permanent,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await ref
        .read(scannerNotifierProvider.notifier)
        .startCleanup(permanent: permanent);

    if (!mounted || success) return;

    final message = ref.read(scannerNotifierProvider).currentProgressLog;
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: message.startsWith('Erro')
            ? Colors.redAccent
            : const Color(0xFF2B2B30),
        duration: const Duration(seconds: 6),
      ),
    );
  }
}

class _RiskSummaryChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _RiskSummaryChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogNotice extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;

  const _DialogNotice({
    required this.text,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
