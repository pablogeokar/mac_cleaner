import 'package:flutter_test/flutter_test.dart';
import 'package:mac_cleaner/features/scanner/domain/entities/deletion_safety_guard.dart';

void main() {
  const home = '/Users/tester';

  group('DeletionSafetyGuard', () {
    test('allows only strict descendants of approved cleanup roots', () {
      expect(
        DeletionSafetyGuard.isSafeToDelete(
          '$home/Library/Caches/app/cache.db',
          homeDirectory: home,
        ),
        isTrue,
      );
      expect(
        DeletionSafetyGuard.isSafeToDelete(
          '$home/Library/Caches',
          homeDirectory: home,
        ),
        isFalse,
      );
    });

    test('blocks system roots and every descendant', () {
      for (final path in [
        '/System',
        '/System/Library/CoreServices/item',
        '/Library/Logs/example.log',
        '/usr/local/bin/tool',
        '/Applications/App.app/Contents/MacOS/App',
      ]) {
        expect(
          DeletionSafetyGuard.isSafeToDelete(path, homeDirectory: home),
          isFalse,
          reason: path,
        );
      }
    });

    test('normalizes traversal before applying policy', () {
      expect(
        DeletionSafetyGuard.isSafeToDelete(
          '$home/Library/Caches/../../../System/secret',
          homeDirectory: home,
        ),
        isFalse,
      );
      expect(
        DeletionSafetyGuard.isSafeToDelete(
          '$home/Library/Caches/app/../app/file',
          homeDirectory: home,
        ),
        isTrue,
      );
    });

    test('does not accept deceptive path prefixes', () {
      expect(
        DeletionSafetyGuard.isSafeToDelete(
          '$home/Library/Caches-Evil/file',
          homeDirectory: home,
        ),
        isFalse,
      );
      expect(
        DeletionSafetyGuard.isSafeToDelete(
          '${home}2/Library/Caches/file',
          homeDirectory: home,
        ),
        isFalse,
      );
    });

    test('honors user exclusions for a folder and its descendants', () {
      final assessment = DeletionSafetyGuard.assess(
        '$home/Documents/Important/report.pdf',
        homeDirectory: home,
        excludedPaths: const ['$home/Documents/Important'],
      );

      expect(assessment.isAllowed, isFalse);
      expect(assessment.reason, contains('configurações'));
    });

    test('blocks roots, relative paths and unknown locations', () {
      for (final path in [
        '/',
        home,
        'Library/Caches/file',
        '$home/Pictures/photo.jpg',
        '/tmp-unapproved/file',
      ]) {
        expect(
          DeletionSafetyGuard.isSafeToDelete(path, homeDirectory: home),
          isFalse,
          reason: path,
        );
      }
    });

    test('allows reviewed user files and aged temporary locations', () {
      for (final path in [
        '$home/Downloads/archive.zip',
        '$home/Desktop/large.mov',
        '$home/Documents/copy.pdf',
        '/private/tmp/old-session/file.tmp',
        '/private/var/tmp/old-file.tmp',
      ]) {
        expect(
          DeletionSafetyGuard.isSafeToDelete(path, homeDirectory: home),
          isTrue,
          reason: path,
        );
      }
    });
  });
}
