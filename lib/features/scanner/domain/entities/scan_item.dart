enum ScanItemType { file, directory, symlink }

class ScanItem {
  final String path;
  final String fileName;
  final int sizeBytes;
  final DateTime lastModified;
  final DateTime lastAccessed;
  final ScanItemType type;
  final bool isSafeToDelete;
  final String? reason;
  final bool isSelected;

  const ScanItem({
    required this.path,
    required this.fileName,
    required this.sizeBytes,
    required this.lastModified,
    required this.lastAccessed,
    required this.type,
    this.isSafeToDelete = true,
    this.reason,
    this.isSelected = true,
  });

  ScanItem copyWith({
    String? path,
    String? fileName,
    int? sizeBytes,
    DateTime? lastModified,
    DateTime? lastAccessed,
    ScanItemType? type,
    bool? isSafeToDelete,
    String? reason,
    bool? isSelected,
  }) {
    return ScanItem(
      path: path ?? this.path,
      fileName: fileName ?? this.fileName,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      lastModified: lastModified ?? this.lastModified,
      lastAccessed: lastAccessed ?? this.lastAccessed,
      type: type ?? this.type,
      isSafeToDelete: isSafeToDelete ?? this.isSafeToDelete,
      reason: reason ?? this.reason,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
