import 'package:flutter/material.dart';
import 'scan_item.dart';

enum ScanCategoryType {
  systemCache,
  systemLogs,
  temporaryFiles,
  trash,
  appCache,
  largeFiles,
  duplicates,
  appResiduals,
  duplicateFonts,
}

class ScanCategory {
  final ScanCategoryType type;
  final String displayName;
  final String description;
  final IconData icon;
  final List<String> targetPaths;
  final int fileCount;
  final int totalBytes;
  final bool isScanning;
  final bool isSelected;
  final List<ScanItem> items;

  const ScanCategory({
    required this.type,
    required this.displayName,
    required this.description,
    required this.icon,
    required this.targetPaths,
    this.fileCount = 0,
    this.totalBytes = 0,
    this.isScanning = false,
    this.isSelected = true,
    this.items = const [],
  });

  ScanCategory copyWith({
    ScanCategoryType? type,
    String? displayName,
    String? description,
    IconData? icon,
    List<String>? targetPaths,
    int? fileCount,
    int? totalBytes,
    bool? isScanning,
    bool? isSelected,
    List<ScanItem>? items,
  }) {
    return ScanCategory(
      type: type ?? this.type,
      displayName: displayName ?? this.displayName,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      targetPaths: targetPaths ?? this.targetPaths,
      fileCount: fileCount ?? this.fileCount,
      totalBytes: totalBytes ?? this.totalBytes,
      isScanning: isScanning ?? this.isScanning,
      isSelected: isSelected ?? this.isSelected,
      items: items ?? this.items,
    );
  }
}
