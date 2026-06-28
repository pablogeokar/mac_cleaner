import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/file_size_formatter.dart';
import '../../dashboard/presentation/widgets/macos_window_shell.dart';

import '../../scanner/domain/entities/scan_item.dart';
import '../../scanner/presentation/providers/scan_provider.dart';
import 'widgets/file_item_row.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  String _searchQuery = '';
  String _sortBy = 'size_desc'; // size_desc, size_asc, name, date_desc

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(scannerNotifierProvider);

    // Watch status changes to auto-navigate to report screen
    ref.listen(scannerNotifierProvider, (previous, next) {
      if (next.status == ScannerStatus.finished) {
        context.go('/report');
      }
    });

    final totalFoundFormatted = FileSizeFormatter.format(
      scanState.categories.fold<int>(0, (sum, cat) => sum + cat.totalBytes),
    );

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
              ],
            ),
            const SizedBox(height: 20),

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
                              hintText: 'Filtrar por nome de arquivo...',
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
                            value: cat.isSelected,
                            activeColor: Theme.of(context).primaryColor,
                            checkColor: Colors.black,
                            onChanged: (val) {
                              ref
                                  .read(scannerNotifierProvider.notifier)
                                  .selectAllInCategory(cat.type, val ?? false);
                            },
                          ),
                          Text(
                            cat.isSelected ? 'Selecionado' : 'Ignorado',
                            style: TextStyle(
                              fontSize: 10,
                              color: cat.isSelected
                                  ? Colors.white54
                                  : Colors.white24,
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
                        onPressed: () {
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
                        onPressed: scanState.totalSelectedFiles > 0
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
                        child: const Text(
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
    var list = items;
    if (_searchQuery.isNotEmpty) {
      list = list
          .where((item) => item.fileName.toLowerCase().contains(_searchQuery))
          .toList();
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

  void _showCleanupConfirmation(BuildContext context) {
    final scanState = ref.read(scannerNotifierProvider);
    final selectedBytes = scanState.totalSelectedBytes;
    final selectedFiles = scanState.totalSelectedFiles;
    final sizeFormatted = FileSizeFormatter.format(selectedBytes);

    bool isPermanent = false;

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
                      });
                    },
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
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    ref
                        .read(scannerNotifierProvider.notifier)
                        .startCleanup(permanent: isPermanent);
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
}
