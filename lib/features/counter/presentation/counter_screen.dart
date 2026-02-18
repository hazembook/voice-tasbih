import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voice_tasbih/core/services/speech_service.dart';
import 'package:voice_tasbih/features/counter/application/counter_notifier.dart';

class CounterScreen extends ConsumerStatefulWidget {
  const CounterScreen({super.key});

  @override
  ConsumerState<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends ConsumerState<CounterScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<String> _logs = [];
  StreamSubscription<String>? _logSubscription;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    final speechService = ref.read(speechServiceProvider);
    _logSubscription = speechService.logStream.listen((log) {
      setState(() {
        _logs.add(log);
      });
      _scrollToBottom();
    });

    await speechService.init();
    setState(() {
      _isInitialized = speechService.isInitialized;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final counterState = ref.watch(counterProvider);
    final counterNotifier = ref.read(counterProvider.notifier);
    final speechService = ref.read(speechServiceProvider);

    return Scaffold(
      backgroundColor: Colors.blueGrey[900],
      appBar: AppBar(
        title: const Text('Voice Tasbih'),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    counterState.isTargetReached
                        ? '✓ Target Reached!'
                        : counterState.phrase,
                    style: const TextStyle(color: Colors.white70, fontSize: 20),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '${counterState.count}',
                    style: TextStyle(
                      color: counterState.isTargetReached
                          ? Colors.greenAccent
                          : Colors.white,
                      fontSize: 120,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Target: ${counterState.target}',
                    style: const TextStyle(color: Colors.white54, fontSize: 18),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          counterNotifier.reset();
                          _addLog('Counter reset');
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          counterNotifier.increment();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('+1'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Divider(color: Colors.white24),
          Container(
            height: 200,
            color: Colors.black,
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Debug Console',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      return Text(
                        _logs[index],
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isInitialized
            ? () async {
                if (counterState.isListening) {
                  await speechService.stop();
                  counterNotifier.toggleListening();
                  _addLog('Listening stopped');
                } else {
                  counterNotifier.toggleListening();
                  await speechService.listen(
                    localeId: 'ar-SA',
                    onResult: (words) {
                      if (words.isNotEmpty) {
                        _checkForDhikr(words, counterNotifier);
                      }
                    },
                  );
                  counterNotifier.toggleListening();
                }
              }
            : null,
        backgroundColor: counterState.isListening ? Colors.red : Colors.green,
        child: Icon(
          counterState.isListening ? Icons.mic_off : Icons.mic,
          size: 32,
          color: Colors.white,
        ),
      ),
    );
  }

  void _addLog(String message) {
    setState(() {
      _logs.add(message);
    });
    _scrollToBottom();
  }

  void _checkForDhikr(String text, CounterNotifier notifier) {
    final lowerText = text.toLowerCase();
    final dhikrPhrases = [
      'سبحان الله',
      'subhan allah',
      'subhanallah',
      'glory be to allah',
    ];

    for (final phrase in dhikrPhrases) {
      if (lowerText.contains(phrase.toLowerCase())) {
        notifier.increment();
        _addLog('Detected: $phrase - Counter incremented');
        return;
      }
    }
    _addLog('Heard: $text (no match)');
  }
}
