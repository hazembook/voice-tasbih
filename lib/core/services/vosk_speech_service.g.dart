// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vosk_speech_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(voskSpeechService)
final voskSpeechServiceProvider = VoskSpeechServiceProvider._();

final class VoskSpeechServiceProvider
    extends
        $FunctionalProvider<
          VoskSpeechService,
          VoskSpeechService,
          VoskSpeechService
        >
    with $Provider<VoskSpeechService> {
  VoskSpeechServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'voskSpeechServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$voskSpeechServiceHash();

  @$internal
  @override
  $ProviderElement<VoskSpeechService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VoskSpeechService create(Ref ref) {
    return voskSpeechService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VoskSpeechService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VoskSpeechService>(value),
    );
  }
}

String _$voskSpeechServiceHash() => r'778f60810eb76823e53e08eb4eb02fdfbbe5fba9';
