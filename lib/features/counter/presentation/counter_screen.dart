import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voice_tasbih/core/services/speech_service.dart';
import 'package:voice_tasbih/features/counter/application/counter_notifier.dart';

class _DhikrOption {
  final String name;
  final String arabic;
  final List<String> patterns;

  const _DhikrOption({
    required this.name,
    required this.arabic,
    required this.patterns,
  });
}

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
  double _counterScale = 1.0;

  final List<_DhikrOption> _dhikrOptions = const [
    _DhikrOption(
      name: 'Subhan Allah',
      arabic: 'سبحان الله',
      patterns: ['سبحان الله', 'سبحان'],
    ),
    _DhikrOption(
      name: 'Alhamdulillah',
      arabic: 'الحمد لله',
      patterns: ['الحمد لله', 'الحمد'],
    ),
    _DhikrOption(
      name: 'Allahu Akbar',
      arabic: 'الله أكبر',
      patterns: ['الله اكبر', 'الله أكبر', 'اكبر'],
    ),
    _DhikrOption(
      name: 'La ilaha illallah',
      arabic: 'لا إله إلا الله',
      patterns: ['لا اله الا الله', 'لا إله إلا الله', 'لا اله'],
    ),
  ];

  final List<int> _targetOptions = [33, 100, 1000];

  _DhikrOption _getCurrentDhikr(String phrase) {
    return _dhikrOptions.firstWhere(
      (d) => d.arabic == phrase,
      orElse: () => _dhikrOptions.first,
    );
  }

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

  void _copyLogs() {
    final text = _logs.join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Debug logs copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  Future<void> _toggleListening() async {
    final speechService = ref.read(speechServiceProvider);
    final counterNotifier = ref.read(counterProvider.notifier);
    final currentState = ref.read(counterProvider);

    if (currentState.isListening) {
      await speechService.stop();
      counterNotifier.setListening(false);
      _addLog('Mic OFF (user stopped)');
    } else {
      counterNotifier.setListening(true);
      _addLog('Mic ON - Listening...');

      await speechService.listen(
        localeId: 'ar-SA',
        onResult: (words, isFinal) {
          if (isFinal && words.isNotEmpty) {
            _checkForDhikr(words, counterNotifier);
          }
        },
        onCancel: () {
          if (mounted) {
            counterNotifier.setListening(false);
            _addLog('Mic OFF');
          }
        },
      );
    }
  }

  void _checkForDhikr(String text, CounterNotifier notifier) {
    final counterState = ref.read(counterProvider);
    final currentDhikr = _getCurrentDhikr(counterState.phrase);

    for (final pattern in currentDhikr.patterns) {
      if (text.contains(pattern)) {
        notifier.increment();
        HapticFeedback.mediumImpact();
        _addLog('✓ ${counterState.count + 1}/${counterState.target}');

        setState(() {
          _counterScale = 1.15;
        });
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {
              _counterScale = 1.0;
            });
          }
        });

        final newState = ref.read(counterProvider);
        if (newState.isTargetReached) {
          HapticFeedback.heavyImpact();
          _addLog('🎉 Target reached!');
          _stopListening();
        }
        return;
      }
    }
    _addLog('✗ "${text.substring(0, text.length > 20 ? 20 : text.length)}..."');
  }

  Future<void> _stopListening() async {
    final speechService = ref.read(speechServiceProvider);
    final counterNotifier = ref.read(counterProvider.notifier);

    await speechService.stop();
    counterNotifier.setListening(false);
  }

  void _showDhikrSelector() {
    final counterNotifier = ref.read(counterProvider.notifier);
    final currentState = ref.read(counterProvider);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Dhikr'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _dhikrOptions.map((dhikr) {
              final isSelected = currentState.phrase == dhikr.arabic;
              return ListTile(
                title: Text(dhikr.name),
                subtitle: Text(
                  dhikr.arabic,
                  style: const TextStyle(fontSize: 18),
                  textAlign: TextAlign.right,
                ),
                trailing: isSelected
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  counterNotifier.setPhrase(dhikr.arabic);
                  counterNotifier.reset();
                  Navigator.pop(context);
                  _addLog('Dhikr changed to: ${dhikr.name}');
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showTargetSelector() {
    final counterNotifier = ref.read(counterProvider.notifier);
    final currentState = ref.read(counterProvider);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Target'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _targetOptions.map((target) {
              final isSelected = currentState.target == target;
              return ListTile(
                title: Text('$target'),
                trailing: isSelected
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  counterNotifier.setTarget(target);
                  counterNotifier.reset();
                  Navigator.pop(context);
                  _addLog('Target changed to: $target');
                },
              );
            }).toList(),
          ),
        );
      },
    );
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
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _showDhikrSelector,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            counterState.phrase,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  AnimatedScale(
                    scale: _counterScale,
                    duration: const Duration(milliseconds: 100),
                    curve: Curves.easeOut,
                    child: Text(
                      '${counterState.count}',
                      style: TextStyle(
                        color: counterState.isTargetReached
                            ? Colors.greenAccent
                            : Colors.white,
                        fontSize: 120,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _showTargetSelector,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Target: ${counterState.target}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white54,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: () {
                      counterNotifier.reset();
                      _addLog('Counter reset to 0');
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset Counter'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
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
                    if (counterState.isListening)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'LISTENING',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(
                        Icons.copy,
                        color: Colors.green,
                        size: 18,
                      ),
                      onPressed: _copyLogs,
                      tooltip: 'Copy logs',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.clear,
                        color: Colors.green,
                        size: 18,
                      ),
                      onPressed: _clearLogs,
                      tooltip: 'Clear logs',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
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
        backgroundColor: counterState.isListening ? Colors.red : Colors.green,
        child: Icon(
          counterState.isListening ? Icons.stop : Icons.mic,
          size: 40,
          color: Colors.white,
        ),
      ),
    );
  }
}
