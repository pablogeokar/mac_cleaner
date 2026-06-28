// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'disk_info_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$diskInfoRepositoryHash() =>
    r'801c79dfd1f52bb19128890a7e58b5d75f416a16';

/// See also [diskInfoRepository].
@ProviderFor(diskInfoRepository)
final diskInfoRepositoryProvider =
    AutoDisposeProvider<DiskInfoRepository>.internal(
      diskInfoRepository,
      name: r'diskInfoRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$diskInfoRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DiskInfoRepositoryRef = AutoDisposeProviderRef<DiskInfoRepository>;
String _$getDiskInfoUseCaseHash() =>
    r'f7584e0de6c2a77f9aaa789dd358bf6b9f16b71d';

/// See also [getDiskInfoUseCase].
@ProviderFor(getDiskInfoUseCase)
final getDiskInfoUseCaseProvider = AutoDisposeProvider<GetDiskInfo>.internal(
  getDiskInfoUseCase,
  name: r'getDiskInfoUseCaseProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$getDiskInfoUseCaseHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef GetDiskInfoUseCaseRef = AutoDisposeProviderRef<GetDiskInfo>;
String _$diskInfoNotifierHash() => r'1a390faa1b401ac1876102bda8f21649b9d27a4e';

/// See also [DiskInfoNotifier].
@ProviderFor(DiskInfoNotifier)
final diskInfoNotifierProvider =
    AutoDisposeAsyncNotifierProvider<DiskInfoNotifier, DiskInfo>.internal(
      DiskInfoNotifier.new,
      name: r'diskInfoNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$diskInfoNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$DiskInfoNotifier = AutoDisposeAsyncNotifier<DiskInfo>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
