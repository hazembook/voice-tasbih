import 'package:freezed_annotation/freezed_annotation.dart';

part 'counter_state.freezed.dart';

@freezed
abstract class CounterState with _$CounterState {
  const factory CounterState({
    @Default(0) int count,
    @Default(33) int target,
    @Default('سبحان الله') String phrase,
    @Default(false) bool isListening,
  }) = _CounterState;

  const CounterState._();

  bool get isTargetReached => count >= target;
}
