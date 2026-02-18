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
  bool _isSpeechInitialized = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    final speechService = ref.read(speechServiceProvider);
    _logSubscription = speechService.logStream.listen((log) {
      _addLog(log);
    });

    final success = await speechService.init();
    setState(() {
      _isSpeechInitialized = success;
    });
    _addLog(success ? 'Speech init: SUCCESS' : 'Speech init: FAILED');
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('[${DateTime.now().toString().substring(11, 19)}] $message');
    });
    _scrollToBottom();
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

  Future<void> _toggleListening() async {
    final speechService = ref.read(speechServiceProvider);
    final counterNotifier = ref.read(counterProvider.notifier);

    if (_isListening) {
      await speechService.stop();
      setState(() {
        _isListening = false;
      });
      _addLog('Mic OFF');
    } else {
      setState(() {
        _isListening = true;
      });
      _addLog('Mic ON - Listening...');

      await speechService.listen(
        localeId: 'ar-SA',
        onResult: (words) {
          if (words.isNotEmpty) {
            _checkForDhikr(words, counterNotifier);
          }
        },
      );

      if (mounted) {
        setState(() {
          _isListening = false;
        });
        _addLog('Mic OFF (auto)');
      }
    }
  }

  void _checkForDhikr(String text, CounterNotifier notifier) {
    _addLog('Heard: "$text"');

    final dhikrPatterns = [
      'سبحان الله',
      'subhan allah',
      'subhanallah',
      'subhan allah',
      'glory be to allah',
    ];

    final lowerText = text.toLowerCase();
    for (final pattern in dhikrPatterns) {
      if (lowerText.contains(pattern.toLowerCase())) {
        notifier.increment();
        _addLog('MATCH: "$pattern" -> Count +1');
        return;
      }
    }
    _addLog('NO MATCH');
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

    return Scaffold(
      backgroundColor: Colors.blueGrey[900],
      appBar: AppBar(
        title: const Text('Voice Tasbih'),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              counterNotifier.reset();
              _addLog('Counter reset to 0');
            },
            tooltip: 'Reset',
          ),
        ],
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
                  const SizedBox(height: 20),
                  if (!_isSpeechInitialized)
                    const Text(
                      'Initializing speech...',
                      style: TextStyle(color: Colors.orange, fontSize: 14),
                    ),
                ],
              ),
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          Container(
            height: 200,
            color: Colors.black,
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Debug Console',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    if (_isListening)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
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
      floatingActionButton: FloatingActionButton.large(
        onPressed: _isSpeechInitialized ? _toggleListening : null,
        backgroundColor: _isListening ? Colors.red : Colors.green,
        child: Icon(
          _isListening ? Icons.mic_off : Icons.mic,
          size: 40,
          color: Colors.white,
        ),
      ),
    );
  }
}
