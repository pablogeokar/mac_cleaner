import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/file_size_formatter.dart';
import '../../../scanner/domain/entities/scan_category.dart';
import '../../../scanner/presentation/providers/scan_provider.dart';

class QuickStatsCard extends ConsumerWidget {
  final ScanCategory category;

  const QuickStatsCard({super.key, required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasScanned = category.fileCount > 0 || category.totalBytes > 0;
    final formattedSize = FileSizeFormatter.format(category.totalBytes);

    return InkWell(
      onTap: () {
        ref
            .read(scannerNotifierProvider.notifier)
            .toggleCategorySelection(category.type);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: category.isSelected
              ? Theme.of(context).primaryColor.withValues(alpha: 0.08)
              : const Color(0xFF242428).withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: category.isSelected
                ? Theme.of(context).primaryColor.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.04),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: category.isSelected
                    ? Theme.of(context).primaryColor.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                category.icon,
                color: category.isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.white60,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    category.displayName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasScanned
                        ? '$formattedSize (${category.fileCount} itens)'
                        : 'Não verificado',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: hasScanned
                          ? FontWeight.w500
                          : FontWeight.normal,
                      color: hasScanned
                          ? (category.totalBytes > 0
                                ? Theme.of(context).primaryColor
                                : Colors.white38)
                          : Colors.white38,
                    ),
                  ),
                ],
              ),
            ),

            // Checkbox
            Checkbox(
              value: category.isSelected,
              activeColor: Theme.of(context).primaryColor,
              checkColor: Colors.black,
              onChanged: (_) {
                ref
                    .read(scannerNotifierProvider.notifier)
                    .toggleCategorySelection(category.type);
              },
            ),
          ],
        ),
      ),
    );
  }
}
