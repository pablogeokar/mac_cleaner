import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/file_size_formatter.dart';
import '../../../scanner/domain/entities/scan_category.dart';
import '../../../scanner/domain/entities/scan_item.dart';
import '../../../scanner/presentation/providers/scan_provider.dart';

class FileItemRow extends ConsumerWidget {
  final ScanItem item;
  final ScanCategoryType categoryType;

  const FileItemRow({
    super.key,
    required this.item,
    required this.categoryType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sizeStr = FileSizeFormatter.format(item.sizeBytes);
    final hasReason = item.reason != null && item.reason!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.01),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.02)),
      ),
      child: Row(
        children: [
          Checkbox(
            value: item.isSelected,
            activeColor: Theme.of(context).primaryColor,
            checkColor: Colors.black,
            onChanged: item.isSafeToDelete
                ? (_) {
                    ref
                        .read(scannerNotifierProvider.notifier)
                        .toggleItemSelection(categoryType, item.path);
                  }
                : null, // Read-only / system protected items cannot be selected
          ),
          const SizedBox(width: 6),
          Icon(
            item.type == ScanItemType.directory
                ? Icons.folder
                : Icons.insert_drive_file,
            size: 16,
            color: Colors.white38,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.fileName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: item.isSafeToDelete
                        ? Colors.white70
                        : Colors.white30,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.path,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (hasReason) ...[
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.reason!,
                      style: TextStyle(
                        fontSize: 9,
                        color: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            sizeStr,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: item.isSafeToDelete ? Colors.white60 : Colors.white24,
            ),
          ),
        ],
      ),
    );
  }
}
