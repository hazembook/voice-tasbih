import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:dhakir/features/counter/domain/models/counter_state.dart';

part 'counter_notifier.g.dart';

@Riverpod(keepAlive: true)
class CounterNotifier extends _$CounterNotifier {
  @override
  CounterState build() {
    return const CounterState();
  }

  void increment() {
    state = state.copyWith(count: state.count + 1);
  }

  void reset() {
    state = state.copyWith(count: 0);
  }

  void setTarget(int target) {
    state = state.copyWith(target: target);
  }

  void setPhrase(String phrase) {
    state = state.copyWith(phrase: phrase);
  }

  void setListening(bool isListening) {
    state = state.copyWith(isListening: isListening);
  }
}
