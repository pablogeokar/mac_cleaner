import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mac_cleaner/core/utils/shell_runner.dart';

void main() {
  test('recursive listing skips excluded folders and their contents', () async {
    final root = await Directory.systemTemp.createTemp('mac_cleaner_test_');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    final included = File('${root.path}/included.log');
    final excludedDirectory = Directory('${root.path}/important');
    final excluded = File('${excludedDirectory.path}/excluded.log');
    await excludedDirectory.create();
    await included.writeAsString('included');
    await excluded.writeAsString('excluded');

    final items = await ShellRunner.listFilesRecursive(
      root.path,
      excludedPaths: [excludedDirectory.path],
    ).toList();

    expect(items.map((item) => item.path), contains(included.path));
    expect(items.map((item) => item.path), isNot(contains(excluded.path)));
  });
}
