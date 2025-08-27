#!/usr/bin/env bash
set -euo pipefail

# =========
# MeghAIna — One-shot project scaffold (Flutter self-evolving assistant)
# =========

APP_NAME="meghaina"
ORG="com.meghaina"

echo "🔧 Creating folders..."
mkdir -p .github/workflows
mkdir -p lib/{assistant,engine,services,security,skills,ui/modules}

# -------- pubspec.yaml --------
cat <<'YAML' > pubspec.yaml
name: meghaina
description: Self-evolving voice assistant with full features (offline install, no OTP).
publish_to: 'none'
version: 0.2.0+1

environment:
  sdk: '>=3.3.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.6
  provider: ^6.1.2
  speech_to_text: ^6.6.2
  flutter_tts: ^3.8.3
  http: ^1.2.2
  shared_preferences: ^2.2.3
  just_audio: ^0.9.42
  audio_session: ^0.1.21
  file_picker: ^8.0.6
  image_picker: ^1.1.2
  image: ^4.2.0
  path_provider: ^2.1.3
  permission_handler: ^11.3.1

flutter:
  uses-material-design: true
YAML

# -------- .github/workflows/flutter.yml --------
cat <<'YAML' > .github/workflows/flutter.yml
name: Build Flutter APK

on:
  push:
    branches: [ "main" ]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Java
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.3'

      # Bootstrap android/ios skeleton if missing (keeps existing lib/)
      - name: Bootstrap Flutter project (android only)
        run: flutter create . --platforms=android --org com.meghaina

      - name: Get dependencies
        run: flutter pub get

      - name: Build release APK (no signing; direct install)
        run: flutter build apk --release

      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: app-release
          path: build/app/outputs/flutter-apk/app-release.apk
YAML

# -------- lib/main.dart --------
cat <<'DART' > lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ui/home.dart';
import 'engine/skill_registry.dart';
import 'skills/note_skill.dart';
import 'skills/http_skill.dart';
import 'skills/tts_skill.dart';
import 'skills/engineering_skill.dart';
import 'skills/security_skill.dart';
import 'skills/deep_search_skill.dart';
import 'skills/iot_skill.dart';
import 'skills/satellite_skill.dart';
import 'skills/music_skill.dart';
import 'skills/media_edit_skill.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final registry = SkillRegistry()
    ..register(NoteSkill())
    ..register(HttpSkill())
    ..register(TtsSkill())
    ..register(EngineeringSkill())
    ..register(SecuritySkill())
    ..register(DeepSearchSkill())
    ..register(IotSkill())
    ..register(SatelliteSkill())
    ..register(MusicSkill())
    ..register(MediaEditSkill());
  runApp(MeghAInaApp(registry: registry));
}

class MeghAInaApp extends StatelessWidget {
  final SkillRegistry registry;
  const MeghAInaApp({super.key, required this.registry});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [Provider<SkillRegistry>.value(value: registry)],
      child: MaterialApp(
        title: 'MeghAIna',
        theme: ThemeData.dark(),
        debugShowCheckedModeBanner: false,
        home: const HomeScreen(),
      ),
    );
  }
}
DART

# -------- lib/ui/home.dart --------
cat <<'DART' > lib/ui/home.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../assistant/voice_assistant.dart';
import '../engine/meghscript.dart';
import '../engine/skill_registry.dart';
import '../engine/s3e_usage.dart';
import 'modules/music_module.dart';
import 'modules/media_edit_module.dart';
import 'modules/deep_search_module.dart';
import 'modules/debug_module.dart';
import 'modules/iot_module.dart';
import 'modules/satellite_module.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final VoiceAssistant _va;
  late final TabController _tabs;
  String transcript = '';
  String output = '';

  @override
  void initState() {
    super.initState();
    _va = VoiceAssistant(onResult: (t) => setState(() => transcript = t));
    _tabs = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _va.dispose();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _runMeghScript(String text) async {
    final registry = context.read<SkillRegistry>();
    final engine = MeghScriptEngine(registry: registry);
    final res = await engine.run(text);
    setState(() => output = res.join('\n'));
    await S3EUsage.logCommand(text);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('MeghAIna · Self-Evolving'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Voice/Script'),
              Tab(text: 'Music'),
              Tab(text: 'Media Edit'),
              Tab(text: 'Deep Search'),
              Tab(text: 'IoT'),
              Tab(text: 'Satellite'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _voiceScriptPane(),
            const MusicModule(),
            const MediaEditModule(),
            const DeepSearchModule(),
            const IotModule(),
            const SatelliteModule(),
          ],
        ),
        floatingActionButton: FutureBuilder<String>(
          future: S3EUsage.recommendShortcut(),
          builder: (c, snap) => snap.hasData && (snap.data ?? '').isNotEmpty
              ? FloatingActionButton.extended(
                  onPressed: () => _runMeghScript(snap.data!),
                  label: const Text('Smart Suggestion'),
                  icon: const Icon(Icons.auto_awesome),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _voiceScriptPane() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(child: ListTile(title: const Text('Transcript'), subtitle: Text(transcript.isEmpty ? 'Say something…' : transcript))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _va.isListening ? _va.stop : _va.start,
                icon: Icon(_va.isListening ? Icons.stop : Icons.mic),
                label: Text(_va.isListening ? 'Stop Listening' : 'Start Voice'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _runMeghScript(transcript),
                child: const Text('Run on Transcript'),
              ),
            )
          ]),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(labelText: 'MeghScript / Natural Command', border: OutlineInputBorder()),
            minLines: 2,
            maxLines: 6,
            onSubmitted: _runMeghScript,
          ),
          const SizedBox(height: 8),
          Expanded(child: SingleChildScrollView(child: Text(output.isEmpty ? 'Output will appear here…' : output))),
        ],
      ),
    );
  }
}
DART

# -------- lib/assistant/voice_assistant.dart --------
cat <<'DART' > lib/assistant/voice_assistant.dart
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class VoiceAssistant {
  final void Function(String) onResult;
  final stt.SpeechToText _stt = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool isListening = false;

  VoiceAssistant({required this.onResult});

  Future<void> start() async {
    final available = await _stt.initialize();
    if (!available) return;
    isListening = true;
    _stt.listen(onResult: (res) => onResult(res.recognizedWords));
  }

  Future<void> stop() async { isListening = false; await _stt.stop(); }
  Future<void> speak(String text) async { await _tts.speak(text); }
  void dispose() { _stt.stop(); _tts.stop(); }
}
DART

# -------- lib/engine/skill_interfaces.dart --------
cat <<'DART' > lib/engine/skill_interfaces.dart
abstract class Skill {
  String get name;
  List<String> get verbs;
  Future<String?> handle(Map<String, dynamic> cmd);
}
DART

# -------- lib/engine/skill_registry.dart --------
cat <<'DART' > lib/engine/skill_registry.dart
import 'skill_interfaces.dart';

class SkillRegistry {
  final Map<String, Skill> _skills = {};
  final Map<String, Skill> _verbIndex = {};

  void register(Skill skill) {
    _skills[skill.name] = skill;
    for (final v in skill.verbs) {
      _verbIndex[v.toLowerCase()] = skill;
    }
  }

  Skill? byVerb(String verb) => _verbIndex[verb.toLowerCase()];
}
DART

# -------- lib/engine/meghscript.dart --------
cat <<'DART' > lib/engine/meghscript.dart
import 'dart:convert';
import 'skill_registry.dart';
import 'skill_interfaces.dart';

class MeghScriptEngine {
  final SkillRegistry registry;
  MeghScriptEngine({required this.registry});

  Future<List<String>> run(String input) async {
    if (input.trim().isEmpty) return ['(no input)'];
    final cmds = _parse(input);
    final outputs = <String>[];
    for (final cmd in cmds) {
      final verb = (cmd['do'] ?? '').toString().toLowerCase();
      final Skill? skill = registry.byVerb(verb);
      if (skill == null) { outputs.add('No skill for verb: $verb'); continue; }
      try { final res = await skill.handle(cmd); outputs.add(res ?? 'OK'); }
      catch (e) { outputs.add('Error: $e'); }
    }
    return outputs;
  }

  List<Map<String, dynamic>> _parse(String input) {
    try {
      final obj = json.decode(input);
      if (obj is Map && obj['plan'] is List) {
        return List<Map<String, dynamic>>.from(obj['plan']);
      }
      if (obj is List) return List<Map<String, dynamic>>.from(obj);
      if (obj is Map) return [Map<String, dynamic>.from(obj)];
    } catch (_) {}
    final t = input.trim().toLowerCase();
    if (t.startsWith('play ') || t.contains('music')) {
      return [{'do': 'music_play', 'query': input.trim()}];
    }
    if (t.contains('note') || t.contains('గుర్తు')) {
      return [{'do': 'save_note', 'text': input.trim()}];
    }
    if (t.contains('sos') || t.contains('emergency')) {
      return [{'do': 'sos_send', 'message': input.trim()}];
    }
    return [{'do': 'save_note', 'text': input.trim()}];
  }
}
DART

# -------- lib/engine/s3e_usage.dart --------
cat <<'DART' > lib/engine/s3e_usage.dart
import 'package:shared_preferences/shared_preferences.dart';

class S3EUsage {
  static const _k = 'megh_usage_counts';

  static Future<void> logCommand(String cmd) async {
    if (cmd.trim().isEmpty) return;
    final p = await SharedPreferences.getInstance();
    final map = Map<String, int>.from((p.getStringList(_k) ?? []).fold<Map<String,int>>({}, (m, line){
      final sp = line.split(':::'); if (sp.length==2) m[sp[0]] = int.parse(sp[1]); return m;
    }));
    map[cmd] = (map[cmd] ?? 0) + 1;
    await p.setStringList(_k, map.entries.map((e)=>'${e.key}:::${e.value}').toList());
  }

  static Future<String> recommendShortcut() async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_k) ?? [];
    if (list.isEmpty) return '';
    list.sort((a,b){ final ai=int.parse(a.split(':::')[1]); final bi=int.parse(b.split(':::')[1]); return bi.compareTo(ai); });
    final top = list.first.split(':::'); if (int.parse(top[1]) < 3) return ''; return top[0];
  }
}
DART

# -------- lib/services/update_service.dart --------
cat <<'DART' > lib/services/update_service.dart
class UpdateService {
  Future<void> checkForUpdates() async {
    // TODO: Pull skill packs from GitHub Releases/self-hosted endpoint
  }
}
DART

# -------- lib/security/anti_tamper.dart --------
cat <<'DART' > lib/security/anti_tamper.dart
import 'dart:io';
import 'package:flutter/foundation.dart';

class AntiTamper {
  static bool get isDebug => kDebugMode;

  static Future<bool> isEmulator() async {
    if (!Platform.isAndroid) return false;
    final props = [
      Platform.environment['ANDROID_AVD_HOME'],
      Platform.environment['ANDROID_HOME'],
    ];
    return props.any((e) => (e ?? '').toLowerCase().contains('emulator'));
  }
}
DART

# -------- skills --------
cat <<'DART' > lib/skills/note_skill.dart
import 'package:shared_preferences/shared_preferences.dart';
import '../engine/skill_interfaces.dart';

class NoteSkill implements Skill {
  @override String get name => 'notes';
  @override List<String> get verbs => ['save_note','get_notes','clear_notes'];
  static const _k = 'megh_notes';

  @override
  Future<String?> handle(Map<String, dynamic> cmd) async {
    final prefs = await SharedPreferences.getInstance();
    final verb = (cmd['do'] ?? '').toString();
    if (verb == 'save_note') {
      final text = (cmd['text'] ?? '').toString();
      final list = prefs.getStringList(_k) ?? []; list.add(text);
      await prefs.setStringList(_k, list); return 'Saved note (${list.length}).';
    }
    if (verb == 'get_notes') {
      final list = prefs.getStringList(_k) ?? [];
      return list.isEmpty ? '(no notes)' : list.asMap().entries.map((e)=>'${e.key+1}. ${e.value}').join('\n');
    }
    if (verb == 'clear_notes') { await prefs.remove(_k); return 'Cleared notes.'; }
    return 'Unknown note verb';
  }
}
DART

cat <<'DART' > lib/skills/http_skill.dart
import 'package:http/http.dart' as http;
import '../engine/skill_interfaces.dart';

class HttpSkill implements Skill {
  @override String get name => 'http';
  @override List<String> get verbs => ['http_get'];

  @override
  Future<String?> handle(Map<String, dynamic> cmd) async {
    final url = (cmd['url'] ?? '').toString();
    if (url.isEmpty) return 'http_get: missing url';
    final resp = await http.get(Uri.parse(url));
    final body = resp.body;
    return 'GET ${resp.statusCode}: ' + (body.length>200? body.substring(0,200)+'…': body);
  }
}
DART

cat <<'DART' > lib/skills/tts_skill.dart
import 'package:flutter_tts/flutter_tts.dart';
import '../engine/skill_interfaces.dart';

class TtsSkill implements Skill {
  @override String get name => 'tts';
  @override List<String> get verbs => ['tts_say','tts_set'];

  final FlutterTts _tts = FlutterTts();
  bool _init = false;

  Future<void> _ensure() async {
    if (_init) return;
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage('te-IN');
    await _tts.setPitch(1.05);
    await _tts.setSpeechRate(0.95);
    _init = true;
  }

  @override
  Future<String?> handle(Map<String, dynamic> cmd) async {
    await _ensure();
    final verb = (cmd['do'] ?? '').toString();
    if (verb == 'tts_say') {
      final text = (cmd['text'] ?? '').toString();
      if (text.isEmpty) return 'tts_say: empty text';
      await _tts.speak(text); return 'speaking';
    }
    if (verb == 'tts_set') {
      if (cmd['lang'] != null) await _tts.setLanguage(cmd['lang']);
      if (cmd['pitch'] != null) await _tts.setPitch((cmd['pitch'] as num).toDouble());
      if (cmd['rate'] != null) await _tts.setSpeechRate((cmd['rate'] as num).toDouble());
      return 'tts configured';
    }
    return 'tts: unknown verb';
  }
}
DART

cat <<'DART' > lib/skills/engineering_skill.dart
import '../engine/skill_interfaces.dart';

class EngineeringSkill implements Skill {
  @override String get name => 'engineering';
  @override List<String> get verbs => ['ohms_v','ohms_i','ohms_r','power_p','series_resistance','parallel_resistance'];

  @override
  Future<String?> handle(Map<String, dynamic> cmd) async {
    final v = (cmd['V'] as num?)?.toDouble();
    final i = (cmd['I'] as num?)?.toDouble();
    final r = (cmd['R'] as num?)?.toDouble();

    switch ((cmd['do'] ?? '').toString()) {
      case 'ohms_v':
        if (i == null || r == null) return 'need I & R';
        return 'V = ${(i*r).toStringAsFixed(4)} V';
      case 'ohms_i':
        if (v == null || r == null || r == 0) return 'need V & R>0';
        return 'I = ${(v/r).toStringAsFixed(6)} A';
      case 'ohms_r':
        if (v == null || i == null || i == 0) return 'need V & I>0';
        return 'R = ${(v/i).toStringAsFixed(4)} Ω';
      case 'power_p':
        if (v != null && i != null) return 'P = ${(v*i).toStringAsFixed(4)} W';
        if (i != null && r != null) return 'P = ${(i*i*r).toStringAsFixed(4)} W';
        if (v != null && r != null && r != 0) return 'P = ${((v*v)/r).toStringAsFixed(4)} W';
        return 'need (V&I) or (I&R) or (V&R)';
      case 'series_resistance':
        final list = (cmd['values'] as List?)?.map((e)=>(e as num).toDouble()).toList() ?? [];
        final sum = list.fold(0.0, (a,b)=>a+b); return 'R_series = ${sum.toStringAsFixed(4)} Ω';
      case 'parallel_resistance':
        final list2 = (cmd['values'] as List?)?.map((e)=>(e as num).toDouble()).toList() ?? [];
        if (list2.isEmpty) return 'no values';
        final inv = list2.fold(0.0, (a,b)=>a+1.0/b); return 'R_parallel = ${(1.0/inv).toStringAsFixed(4)} Ω';
    }
    return 'engineering: unknown verb';
  }
}
DART

cat <<'DART' > lib/skills/security_skill.dart
import '../engine/skill_interfaces.dart';
import '../security/anti_tamper.dart';

class SecuritySkill implements Skill {
  @override String get name => 'security';
  @override List<String> get verbs => ['security_status'];

  @override
  Future<String?> handle(Map<String, dynamic> cmd) async {
    final dbg = AntiTamper.isDebug;
    final emu = await AntiTamper.isEmulator();
    return 'Security: debug=${dbg ? 'on' : 'off'}, emulator=${emu ? 'yes' : 'no'}';
  }
}
DART

cat <<'DART' > lib/skills/deep_search_skill.dart
import 'package:http/http.dart' as http;
import '../engine/skill_interfaces.dart';

class DeepSearchSkill implements Skill {
  @override String get name => 'deep_search';
  @override List<String> get verbs => ['search_http'];

  @override
  Future<String?> handle(Map<String, dynamic> cmd) async {
    final url = (cmd['url'] ?? '').toString();
    if (url.isEmpty) return 'search_http: missing url';
    final r = await http.get(Uri.parse(url));
    return 'search_http ${r.statusCode}: ' + (r.body.length>300? r.body.substring(0,300)+'…' : r.body);
  }
}
DART

cat <<'DART' > lib/skills/iot_skill.dart
import '../engine/skill_interfaces.dart';

class IotSkill implements Skill {
  @override String get name => 'iot';
  @override List<String> get verbs => ['iot_command'];

  @override
  Future<String?> handle(Map<String, dynamic> cmd) async {
    final device = (cmd['device'] ?? '').toString();
    final action = (cmd['action'] ?? '').toString();
    return 'IoT → $device : $action (stub)';
  }
}
DART

cat <<'DART' > lib/skills/satellite_skill.dart
import '../engine/skill_interfaces.dart';

class SatelliteSkill implements Skill {
  @override String get name => 'satellite';
  @override List<String> get verbs => ['sos_send'];

  @override
  Future<String?> handle(Map<String, dynamic> cmd) async {
    final msg = (cmd['message'] ?? 'SOS').toString();
    return 'SkyCall queued: $msg';
  }
}
DART

cat <<'DART' > lib/skills/music_skill.dart
import 'package:just_audio/just_audio.dart';
import '../engine/skill_interfaces.dart';

class MusicSkill implements Skill {
  @override String get name => 'music';
  @override List<String> get verbs => ['music_load','music_play','music_pause','music_stop'];
  final _player = AudioPlayer();

  @override
  Future<String?> handle(Map<String, dynamic> cmd) async {
    final verb = (cmd['do'] ?? '').toString();
    switch (verb) {
      case 'music_load':
        final u
