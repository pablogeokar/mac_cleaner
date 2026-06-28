import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/disk_info_repository_impl.dart';
import '../../domain/entities/disk_info.dart';
import '../../domain/repositories/disk_info_repository.dart';
import '../../domain/use_cases/get_disk_info.dart';

part 'disk_info_provider.g.dart';

@riverpod
DiskInfoRepository diskInfoRepository(Ref ref) {
  return DiskInfoRepositoryImpl();
}

@riverpod
GetDiskInfo getDiskInfoUseCase(Ref ref) {
  return GetDiskInfo(ref.watch(diskInfoRepositoryProvider));
}

@riverpod
class DiskInfoNotifier extends _$DiskInfoNotifier {
  @override
  FutureOr<DiskInfo> build() {
    return ref.watch(getDiskInfoUseCaseProvider).call();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(getDiskInfoUseCaseProvider).call(),
    );
  }
}
