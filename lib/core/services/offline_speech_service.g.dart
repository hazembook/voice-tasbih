// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_speech_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(offlineSpeechService)
final offlineSpeechServiceProvider = OfflineSpeechServiceProvider._();

final class OfflineSpeechServiceProvider
    extends
        $FunctionalProvider<
          OfflineSpeechService,
          OfflineSpeechService,
          OfflineSpeechService
        >
    with $Provider<OfflineSpeechService> {
  OfflineSpeechServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'offlineSpeechServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$offlineSpeechServiceHash();

  @$internal
  @override
  $ProviderElement<OfflineSpeechService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  OfflineSpeechService create(Ref ref) {
    return offlineSpeechService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OfflineSpeechService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OfflineSpeechService>(value),
    );
  }
}

String _$offlineSpeechServiceHash() =>
    r'b1e59fe9381897b45cef6c50f28d8bda4f7cce28';
