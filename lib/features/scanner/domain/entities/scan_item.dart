enum ScanItemType { file, directory, symlink }

enum ScanRiskLevel { safe, caution, protected }

class ScanItem {
  final String path;
  final String fileName;
  final int sizeBytes;
  final DateTime lastModified;
  final DateTime lastAccessed;
  final ScanItemType type;
  final bool isSafeToDelete;
  final ScanRiskLevel riskLevel;
  final String? reason;
  final bool isSelected;

  bool get canBeSelected =>
      isSafeToDelete && riskLevel != ScanRiskLevel.protected;

  const ScanItem({
    required this.path,
    required this.fileName,
    required this.sizeBytes,
    required this.lastModified,
    required this.lastAccessed,
    required this.type,
    this.isSafeToDelete = true,
    this.riskLevel = ScanRiskLevel.safe,
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
    ScanRiskLevel? riskLevel,
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
      riskLevel: riskLevel ?? this.riskLevel,
      reason: reason ?? this.reason,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
