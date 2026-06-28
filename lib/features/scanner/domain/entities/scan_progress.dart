import 'scan_category.dart';
import 'scan_item.dart';

class ScanProgress {
  final ScanCategoryType category;
  final double progress; // 0.0 to 1.0
  final String currentPath;
  final int itemsFound;
  final int bytesFound;
  final bool isComplete;
  final List<ScanItem> items;

  const ScanProgress({
    required this.category,
    required this.progress,
    required this.currentPath,
    required this.itemsFound,
    required this.bytesFound,
    required this.isComplete,
    this.items = const [],
  });
}
