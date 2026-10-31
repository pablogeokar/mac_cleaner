import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mac_cleaner/features/scanner/data/repositories/file_scanner_repository_impl.dart';
import 'package:mac_cleaner/features/scanner/domain/entities/scan_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'permission refusal preserves the file and explains the failure',
    () async {
      if (!Platform.isMacOS) return;

      final directory = await Directory(
        '/private/tmp',
      ).createTemp('maccleaner-permission-test-');
      final file = await File(
        '${directory.path}/candidate.txt',
      ).writeAsString('keep this file');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel('maccleaner/recycle');
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(
          code: 'RECYCLE_ERROR',
          message: 'You do not have permission to move the file',
        );
      });
      addTearDown(() async {
        messenger.setMockMethodCallHandler(channel, null);
        await directory.delete(recursive: true);
      });

      final item = ScanItem(
        path: file.path,
        fileName: 'candidate.txt',
        sizeBytes: await file.length(),
        lastModified: DateTime(2026),
        lastAccessed: DateTime(2026),
        type: ScanItemType.file,
      );
      final result = await FileScannerRepositoryImpl().deleteItems([
        item,
      ], permanent: false);

      expect(result.removedCount, 0);
      expect(result.failedCount, 1);
      expect(result.permissionDeniedPaths, contains(file.path));
      expect(result.failedItems[file.path], contains('macOS negou permissão'));
      expect(await file.exists(), isTrue);
    },
  );
}
