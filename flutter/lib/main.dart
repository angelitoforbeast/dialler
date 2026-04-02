import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const String serverUrl = 'http://72.62.75.18:8000/api';
const _recorderChannel = MethodChannel('com.callcenter.simple_dialer/recorder');

void main() => runApp(const SimpleDialerApp());

class SimpleDialerApp extends StatelessWidget {
  const SimpleDialerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dialer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0D47A1),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _tab = 0;
  final _pages = const [DialerPage(), RecentPage(), RecordingsPage(), SettingsPage()];

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [Permission.microphone, Permission.phone].request();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dialpad), label: 'Dialer'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Recent'),
          NavigationDestination(icon: Icon(Icons.cloud_done), label: 'Uploaded'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class DialerPage extends StatefulWidget {
  const DialerPage({super.key});
  @override
  State<DialerPage> createState() => _DialerPageState();
}

class _DialerPageState extends State<DialerPage> {
  String _number = '';
  bool _isRecording = false;
  int _seconds = 0;
  Timer? _timer;
  String? _currentPath;

  void _addDigit(String d) => setState(() => _number += d);
  void _backspace() {
    if (_number.isNotEmpty) setState(() => _number = _number.substring(0, _number.length - 1));
  }

  Future<void> _call() async {
    if (_number.isEmpty) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      _currentPath = '${dir.path}/call_$ts.m4a';
      await _recorderChannel.invokeMethod('startRecording', {'path': _currentPath});
      setState(() { _isRecording = true; _seconds = 0; });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _seconds++);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mic error: $e'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    final uri = Uri(scheme: 'tel', path: _number);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _stopAndSave() async {
    _timer?.cancel();
    _timer = null;
    try { await _recorderChannel.invokeMethod('stopRecording'); } catch (_) {}
    if (_currentPath != null) {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList('call_history') ?? [];
      history.insert(0, jsonEncode({
        'number': _number, 'duration': _seconds, 'path': _currentPath,
        'date': DateTime.now().toIso8601String(), 'uploaded': false,
      }));
      await prefs.setStringList('call_history', history);
      _uploadRecording(_currentPath!, _number, _seconds);
    }
    setState(() { _isRecording = false; _seconds = 0; _currentPath = null; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording saved & uploading...'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _uploadRecording(String path, String number, int duration) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final agentName = prefs.getString('agent_name') ?? 'Agent';
      final request = http.MultipartRequest('POST', Uri.parse('$serverUrl/upload-recording'));
      request.headers['Accept'] = 'application/json';
      request.fields['caller'] = agentName;
      request.fields['callee'] = number;
      request.fields['duration'] = duration.toString();
      request.fields['status'] = 'ANSWERED';
      request.files.add(await http.MultipartFile.fromPath('recording', path));
      final response = await request.send();
      if (response.statusCode == 200) {
        final history = prefs.getStringList('call_history') ?? [];
        for (int i = 0; i < history.length; i++) {
          final item = jsonDecode(history[i]);
          if (item['path'] == path) {
            item['uploaded'] = true;
            history[i] = jsonEncode(item);
            break;
          }
        }
        await prefs.setStringList('call_history', history);
      }
    } catch (_) {}
  }

  String get _timerText {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Dialer', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true, elevation: 0,
        backgroundColor: Colors.transparent, foregroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          if (_isRecording)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              color: Colors.red,
              child: Row(
                children: [
                  const Icon(Icons.fiber_manual_record, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text('REC  $_timerText',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _stopAndSave,
                    icon: const Icon(Icons.stop, color: Colors.red),
                    label: const Text('End & Save'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.red),
                  ),
                ],
              ),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _number.isEmpty ? 'Enter number' : _number,
              style: TextStyle(
                fontSize: _number.length > 12 ? 28 : 36, fontWeight: FontWeight.w300,
                color: _number.isEmpty ? Colors.grey : Colors.black87, letterSpacing: 2,
              ),
              textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
                for (final row in [['1','2','3'],['4','5','6'],['7','8','9'],['*','0','#']])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: row.map((d) => _DialButton(digit: d, onTap: () => _addDigit(d))).toList(),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const SizedBox(width: 64),
                GestureDetector(
                  onTap: _isRecording ? null : _call,
                  child: Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(color: _isRecording ? Colors.grey : Colors.green, shape: BoxShape.circle),
                    child: const Icon(Icons.call, color: Colors.white, size: 32),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: IconButton(
                    onPressed: _backspace,
                    onLongPress: () => setState(() => _number = ''),
                    icon: const Icon(Icons.backspace_outlined, color: Colors.grey, size: 28),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _DialButton extends StatelessWidget {
  final String digit;
  final VoidCallback onTap;
  const _DialButton({required this.digit, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72, height: 72,
        decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
        child: Center(child: Text(digit, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w400))),
      ),
    );
  }
}

class RecentPage extends StatefulWidget {
  const RecentPage({super.key});
  @override
  State<RecentPage> createState() => _RecentPageState();
}

class _RecentPageState extends State<RecentPage> {
  List<Map<String, dynamic>> _calls = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('call_history') ?? [];
    setState(() { _calls = history.map((e) => jsonDecode(e) as Map<String, dynamic>).toList(); });
  }

  Future<void> _retryUpload(Map<String, dynamic> call) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final agentName = prefs.getString('agent_name') ?? 'Agent';
      final path = call['path'] as String;
      final file = File(path);
      if (!await file.exists()) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File not found'), backgroundColor: Colors.red));
        return;
      }
      final request = http.MultipartRequest('POST', Uri.parse('$serverUrl/upload-recording'));
      request.headers['Accept'] = 'application/json';
      request.fields['caller'] = agentName;
      request.fields['callee'] = call['number'] ?? '';
      request.fields['duration'] = (call['duration'] ?? 0).toString();
      request.fields['status'] = 'ANSWERED';
      request.files.add(await http.MultipartFile.fromPath('recording', path));
      final response = await request.send();
      if (response.statusCode == 200) {
        final history = prefs.getStringList('call_history') ?? [];
        for (int i = 0; i < history.length; i++) {
          final item = jsonDecode(history[i]);
          if (item['path'] == path) { item['uploaded'] = true; history[i] = jsonEncode(item); break; }
        }
        await prefs.setStringList('call_history', history);
        _load();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploaded!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
  }

  String _fmt(dynamic s) {
    final sec = (s is int) ? s : int.tryParse(s.toString()) ?? 0;
    return '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    try { return DateFormat('MMM dd, HH:mm').format(DateTime.parse(iso)); } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent Calls', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true, elevation: 0, backgroundColor: Colors.transparent, foregroundColor: Colors.black87,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _calls.isEmpty
          ? const Center(child: Text('No calls yet', style: TextStyle(color: Colors.grey, fontSize: 16)))
          : ListView.builder(
              itemCount: _calls.length,
              itemBuilder: (context, i) {
                final c = _calls[i];
                final uploaded = c['uploaded'] == true;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: uploaded ? Colors.green.shade50 : Colors.orange.shade50,
                    child: Icon(uploaded ? Icons.cloud_done : Icons.cloud_upload, color: uploaded ? Colors.green : Colors.orange),
                  ),
                  title: Text(c['number'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${_fmt(c['duration'])}  •  ${_fmtDate(c['date'])}', style: const TextStyle(fontSize: 13)),
                  trailing: uploaded
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : IconButton(icon: const Icon(Icons.upload, color: Colors.orange), onPressed: () => _retryUpload(c)),
                );
              },
            ),
    );
  }
}

class RecordingsPage extends StatefulWidget {
  const RecordingsPage({super.key});
  @override
  State<RecordingsPage> createState() => _RecordingsPageState();
}

class _RecordingsPageState extends State<RecordingsPage> {
  List<dynamic> _recordings = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await http.get(Uri.parse('$serverUrl/recordings/all'), headers: {'Accept': 'application/json'});
      final data = jsonDecode(resp.body);
      setState(() { _recordings = data['data'] ?? []; _loading = false; });
    } catch (e) { setState(() => _loading = false); }
  }

  String _fmt(dynamic s) {
    final sec = int.tryParse(s.toString()) ?? 0;
    return '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Server Recordings', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true, elevation: 0, backgroundColor: Colors.transparent, foregroundColor: Colors.black87,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _recordings.isEmpty
              ? const Center(child: Text('No recordings on server', style: TextStyle(color: Colors.grey)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _recordings.length,
                    itemBuilder: (context, i) {
                      final r = _recordings[i];
                      return ListTile(
                        leading: CircleAvatar(backgroundColor: Colors.blue.shade50, child: const Icon(Icons.audiotrack, color: Colors.blue)),
                        title: Text('${r['caller'] ?? '?'} -> ${r['callee'] ?? '?'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${_fmt(r['duration'])}  •  ${r['created_at'] ?? ''}', style: const TextStyle(fontSize: 13)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Text(r['status'] ?? '', style: TextStyle(fontSize: 11, color: Colors.green.shade700)),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _nameController = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _nameController.text = prefs.getString('agent_name') ?? '';
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('agent_name', _nameController.text.trim());
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved!'), backgroundColor: Colors.green));
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('call_history');
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('History cleared'), backgroundColor: Colors.orange));
  }

  @override
  void dispose() { _nameController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true, elevation: 0, backgroundColor: Colors.transparent, foregroundColor: Colors.black87,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Agent Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'Enter your name (shown in recordings)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('Save')),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          const Text('Server', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 8),
          Text(serverUrl, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: _clearHistory,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text('Clear Call History', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
