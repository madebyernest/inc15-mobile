```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpException;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const TriviaApp());

class TriviaApp extends StatelessWidget {
  const TriviaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Trivia Showdown',
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: const TriviaScreen(),
      );
}

String decodeEntities(String input) {
  const named = {
    'quot': '"', 'amp': '&', 'lt': '<', 'gt': '>', 'apos': "'",
    'eacute': 'é', 'egrave': 'è', 'aacute': 'á', 'iacute': 'í',
    'oacute': 'ó', 'uacute': 'ú', 'ntilde': 'ñ', 'ouml': 'ö',
    'uuml': 'ü', 'auml': 'ä', 'ccedil': 'ç', 'hellip': '…',
    'ldquo': '“', 'rdquo': '”', 'lsquo': '‘', 'rsquo': '’',
    'ndash': '–', 'mdash': '—', 'deg': '°', 'shy': '',
  };
  return input.replaceAllMapped(
      RegExp(r'&(#x[0-9a-fA-F]+|#\d+|[a-zA-Z]+);'), (m) {
    final code = m.group(1)!;
    if (code.startsWith('#x')) {
      return String.fromCharCode(int.parse(code.substring(2), radix: 16));
    }
    if (code.startsWith('#')) {
      return String.fromCharCode(int.parse(code.substring(1)));
    }
    return named[code] ?? m.group(0)!;
  });
}

class Question {
  final String text;
  final String correct;
  final List<String> options;

  Question({required this.text, required this.correct, required this.options});

  factory Question.fromJson(Map<String, dynamic> json) {
    final correct = decodeEntities(json['correct_answer'] as String);
    final options = (json['incorrect_answers'] as List<dynamic>)
        .map((e) => decodeEntities(e as String))
        .toList()
      ..add(correct)
      ..shuffle(Random());
    return Question(
      text: decodeEntities(json['question'] as String),
      correct: correct,
      options: options,
    );
  }
}

enum LoadState { loading, ready, error }

enum SyncState { idle, syncing, synced }

class TriviaScreen extends StatefulWidget {
  const TriviaScreen({super.key});

  @override
  State<TriviaScreen> createState() => _TriviaScreenState();
}

class _TriviaScreenState extends State<TriviaScreen> {
  static const _url =
      'https://opentdb.com/api.php?amount=5&category=9&difficulty=easy&type=multiple';

  LoadState _load = LoadState.loading;
  String _error = '';
  List<Question> _questions = [];
  int _index = 0;
  int _score = 0;
  String? _selected;
  SyncState _sync = SyncState.idle;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    setState(() {
      _load = LoadState.loading;
      _index = 0;
      _score = 0;
      _selected = null;
      _sync = SyncState.idle;
    });
    try {
      final response =
          await http.get(Uri.parse(_url)).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw HttpException('Server returned HTTP ${response.statusCode}.');
      }
      final data = json.decode(response.body) as Map<String, dynamic>;
      final code = data['response_code'];
      if (code != 0) {
        throw FormatException('Trivia API returned response_code $code.');
      }
      final results = data['results'] as List<dynamic>;
      if (results.isEmpty) {
        throw const FormatException('No questions were returned.');
      }
      final questions = results
          .map((e) => Question.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _load = LoadState.ready;
      });
    } on TimeoutException {
      _fail('The request timed out. Check your connection and try again.');
    } on HttpException catch (e) {
      _fail(e.message);
    } on FormatException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Could not load questions. Check your connection and try again.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _load = LoadState.error;
    });
  }

  void _answer(String option) {
    if (_selected != null) return;
    setState(() {
      _selected = option;
      if (option == _questions[_index].correct) _score++;
    });
  }

  void _next() => setState(() {
        _index++;
        _selected = null;
      });

  Future<void> _syncScoreToCloud() async {
    setState(() => _sync = SyncState.syncing);
    final payload = {'score': _score, 'total': _questions.length};
    debugPrint('Simulated payload (not sent): ${json.encode(payload)}');
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _sync = SyncState.synced);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('SIMULATION: score marked synced. No data was sent.')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Trivia Showdown')),
        body: Padding(padding: const EdgeInsets.all(16), child: _body()),
      );

  Widget _body() {
    switch (_load) {
      case LoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case LoadState.error:
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _fetchQuestions, child: const Text('Retry')),
          ]),
        );
      case LoadState.ready:
        return _index >= _questions.length ? _results() : _questionView();
    }
  }

  Widget _questionView() {
    final q = _questions[_index];
    final answered = _selected != null;
    return ListView(children: [
      Text('Question ${_index + 1} of ${_questions.length}   •   Score: $_score',
          style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 8),
      LinearProgressIndicator(
          value: (_index + (answered ? 1 : 0)) / _questions.length),
      const SizedBox(height: 24),
      Text(q.text, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      for (final option in q.options)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _optionColor(q, option),
              disabledBackgroundColor: _optionColor(q, option),
              disabledForegroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
            ),
            onPressed: answered ? null : () => _answer(option),
            child: Text(option, textAlign: TextAlign.center),
          ),
        ),
      if (answered)
        FilledButton.tonal(
          onPressed: _next,
          child: Text(_index == _questions.length - 1 ? 'Finish' : 'Next'),
        ),
    ]);
  }

  Color? _optionColor(Question q, String option) {
    if (_selected == null) return null;
    if (option == q.correct) return Colors.green.shade700;
    if (option == _selected) return Colors.red.shade700;
    return Colors.grey.shade500;
  }

  Widget _results() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Round complete!',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text('Final score: $_score / ${_questions.length}',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _sync == SyncState.idle ? _syncScoreToCloud : null,
            icon: _sync == SyncState.syncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_upload),
            label: Text(switch (_sync) {
              SyncState.idle => 'Sync Score to Leaderboard (simulated)',
              SyncState.syncing => 'Syncing (simulated)...',
              SyncState.synced => 'Synced (simulation only)',
            }),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
              onPressed: _fetchQuestions, child: const Text('Play again')),
        ]),
      );
}