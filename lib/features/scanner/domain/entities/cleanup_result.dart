import 'scan_item.dart';

class CleanupResult {
  final List<ScanItem> removedItems;
  final Map<String, String> skippedItems;
  final Map<String, String> failedItems;

  const CleanupResult({
    this.removedItems = const [],
    this.skippedItems = const {},
    this.failedItems = const {},
  });

  int get removedBytes =>
      removedItems.fold<int>(0, (total, item) => total + item.sizeBytes);

  int get removedCount => removedItems.length;
  int get skippedCount => skippedItems.length;
  int get failedCount => failedItems.length;
}
