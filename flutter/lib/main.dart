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

const String serverUrl = 'http://72.62.75.18:8000/api';

const _callChannel = MethodChannel('com.callcenter.simple_dialer/calls');
const _recorderChannel = MethodChannel('com.callcenter.simple_dialer/recorder');
const _callEvents = EventChannel('com.callcenter.simple_dialer/call_events');

void main() => runApp(const SimpleDialerApp());

class SimpleDialerApp extends StatelessWidget {
  const SimpleDialerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dialer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF0D47A1), useMaterial3: true),
      home: const MainScreen(),
    );
  }
}

// ─── MAIN SCREEN ────────────────────────────────────────────────────────────

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _tab = 0;
  bool _inCall = false;
  String _callNumber = '';
  String _callState = '';
  int _callSeconds = 0;
  Timer? _callTimer;
  bool _isMuted = false;
  bool _isSpeaker = false;
  bool _isRecording = false;
  String? _recordingPath;
  StreamSubscription? _callEventsSub;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _listenCallEvents();
    _setupMethodCallHandler();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.microphone,
      Permission.phone,
    ].request();
  }

  void _setupMethodCallHandler() {
    _callChannel.setMethodCallHandler((call) async {
      if (call.method == 'incomingDial') {
        final number = call.arguments as String?;
        if (number != null && number.isNotEmpty) {
          setState(() {
            _tab = 0; // Switch to dialer
          });
          // The dialer page will handle this via a global key or we set the number
          _pendingDialNumber = number;
        }
      }
    });
  }

  String? _pendingDialNumber;

  void _listenCallEvents() {
    _callEventsSub = _callEvents.receiveBroadcastStream().listen((event) {
      final data = Map<String, dynamic>.from(event);
      final stateStr = data['stateStr'] as String;
      final number = data['number'] as String? ?? '';

      setState(() {
        _callState = stateStr;
        if (number.isNotEmpty) _callNumber = number;
      });

      if (stateStr == 'ACTIVE' && !_inCall) {
        setState(() => _inCall = true);
        _startCallTimer();
        _startRecording();
      } else if (stateStr == 'DIALING' || stateStr == 'CONNECTING') {
        setState(() => _inCall = true);
      } else if (stateStr == 'DISCONNECTED') {
        _onCallEnded();
      }
    });
  }

  void _startCallTimer() {
    _callSeconds = 0;
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _callSeconds++);
    });
  }

  Future<void> _startRecording() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      _recordingPath = '${dir.path}/call_$ts.m4a';
      await _recorderChannel.invokeMethod('startRecording', {'path': _recordingPath});
      setState(() => _isRecording = true);
    } catch (_) {}
  }

  Future<void> _onCallEnded() async {
    _callTimer?.cancel();
    _callTimer = null;

    // Stop recording
    if (_isRecording) {
      try { await _recorderChannel.invokeMethod('stopRecording'); } catch (_) {}
    }

    // Save to history and upload
    if (_recordingPath != null && _callSeconds > 0) {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList('call_history') ?? [];
      history.insert(0, jsonEncode({
        'number': _callNumber, 'duration': _callSeconds, 'path': _recordingPath,
        'date': DateTime.now().toIso8601String(), 'uploaded': false,
      }));
      await prefs.setStringList('call_history', history);
      _uploadRecording(_recordingPath!, _callNumber, _callSeconds);
    }

    setState(() {
      _inCall = false;
      _callState = '';
      _callSeconds = 0;
      _isMuted = false;
      _isSpeaker = false;
      _isRecording = false;
      _recordingPath = null;
    });
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

  void makeCall(String number) async {
    if (number.isEmpty) return;
    setState(() { _callNumber = number; _inCall = true; _callState = 'DIALING'; });
    try {
      await _callChannel.invokeMethod('placeCall', {'number': number});
    } catch (e) {
      setState(() { _inCall = false; _callState = ''; });
    }
  }

  void endCall() async {
    try { await _callChannel.invokeMethod('endCall'); } catch (_) {}
  }

  void toggleMute() async {
    setState(() => _isMuted = !_isMuted);
    try { await _callChannel.invokeMethod('muteCall', {'mute': _isMuted}); } catch (_) {}
  }

  void toggleSpeaker() async {
    setState(() => _isSpeaker = !_isSpeaker);
    try { await _callChannel.invokeMethod('speakerOn', {'on': _isSpeaker}); } catch (_) {}
  }

  String get _timerText {
    final m = (_callSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_callSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _callEventsSub?.cancel();
    _callTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show in-call screen when in a call
    if (_inCall) {
      return InCallScreen(
        number: _callNumber,
        state: _callState,
        timer: _timerText,
        isMuted: _isMuted,
        isSpeaker: _isSpeaker,
        isRecording: _isRecording,
        onEndCall: endCall,
        onToggleMute: toggleMute,
        onToggleSpeaker: toggleSpeaker,
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          DialerPage(onCall: makeCall, pendingNumber: _pendingDialNumber),
          const RecentPage(),
          const RecordingsPage(),
          const SettingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          _pendingDialNumber = null;
        },
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

// ─── IN-CALL SCREEN ─────────────────────────────────────────────────────────

class InCallScreen extends StatelessWidget {
  final String number;
  final String state;
  final String timer;
  final bool isMuted;
  final bool isSpeaker;
  final bool isRecording;
  final VoidCallback onEndCall;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleSpeaker;

  const InCallScreen({
    super.key, required this.number, required this.state, required this.timer,
    required this.isMuted, required this.isSpeaker, required this.isRecording,
    required this.onEndCall, required this.onToggleMute, required this.onToggleSpeaker,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = state == 'ACTIVE';
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            // Number
            Text(number, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w300, letterSpacing: 2)),
            const SizedBox(height: 12),
            // State / Timer
            Text(
              isActive ? timer : state,
              style: TextStyle(color: isActive ? Colors.greenAccent : Colors.white70, fontSize: 20, fontWeight: FontWeight.w400),
            ),
            const SizedBox(height: 8),
            // Recording indicator
            if (isRecording)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  const Text('Recording', style: TextStyle(color: Colors.redAccent, fontSize: 14)),
                ],
              ),
            const Spacer(flex: 3),
            // Call controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CallButton(
                  icon: isMuted ? Icons.mic_off : Icons.mic,
                  label: isMuted ? 'Unmute' : 'Mute',
                  color: isMuted ? Colors.red : Colors.white24,
                  onTap: onToggleMute,
                ),
                _CallButton(
                  icon: isSpeaker ? Icons.volume_up : Icons.volume_down,
                  label: isSpeaker ? 'Speaker On' : 'Speaker',
                  color: isSpeaker ? Colors.blue : Colors.white24,
                  onTap: onToggleSpeaker,
                ),
              ],
            ),
            const SizedBox(height: 40),
            // End call button
            GestureDetector(
              onTap: onEndCall,
              child: Container(
                width: 80, height: 80,
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: const Icon(Icons.call_end, color: Colors.white, size: 36),
              ),
            ),
            const SizedBox(height: 16),
            const Text('End Call', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _CallButton({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

// ─── DIALER PAGE ────────────────────────────────────────────────────────────

class DialerPage extends StatefulWidget {
  final Function(String) onCall;
  final String? pendingNumber;
  const DialerPage({super.key, required this.onCall, this.pendingNumber});
  @override
  State<DialerPage> createState() => _DialerPageState();
}

class _DialerPageState extends State<DialerPage> {
  String _number = '';
  bool _defaultDialerChecked = false;

  @override
  void initState() {
    super.initState();
    if (widget.pendingNumber != null && widget.pendingNumber!.isNotEmpty) {
      _number = widget.pendingNumber!;
    }
    _checkDefaultDialer();
  }

  @override
  void didUpdateWidget(DialerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pendingNumber != null && widget.pendingNumber != oldWidget.pendingNumber) {
      setState(() => _number = widget.pendingNumber!);
    }
  }

  Future<void> _checkDefaultDialer() async {
    try {
      final isDefault = await _callChannel.invokeMethod('isDefaultDialer');
      setState(() => _defaultDialerChecked = isDefault == true);
    } catch (_) {}
  }

  Future<void> _requestDefaultDialer() async {
    try {
      await _callChannel.invokeMethod('requestDefaultDialer');
      await Future.delayed(const Duration(seconds: 2));
      _checkDefaultDialer();
    } catch (_) {}
  }

  void _addDigit(String d) => setState(() => _number += d);
  void _backspace() {
    if (_number.isNotEmpty) setState(() => _number = _number.substring(0, _number.length - 1));
  }

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
          // Default dialer banner
          if (!_defaultDialerChecked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              color: Colors.orange.shade50,
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Set as default phone app for in-app calling',
                      style: TextStyle(color: Colors.orange.shade900, fontSize: 13))),
                  TextButton(
                    onPressed: _requestDefaultDialer,
                    child: const Text('Set Now', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

          const Spacer(),

          // Number display
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

          // Dial pad
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

          // Call + backspace
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const SizedBox(width: 64),
                GestureDetector(
                  onTap: () => widget.onCall(_number),
                  child: Container(
                    width: 72, height: 72,
                    decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
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

// ─── RECENT CALLS ───────────────────────────────────────────────────────────

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
      if (!await File(path).exists()) {
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

// ─── SERVER RECORDINGS ──────────────────────────────────────────────────────

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

// ─── SETTINGS ───────────────────────────────────────────────────────────────

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _nameController = TextEditingController();
  bool _isDefaultDialer = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _nameController.text = prefs.getString('agent_name') ?? '';
    try {
      final isDefault = await _callChannel.invokeMethod('isDefaultDialer');
      setState(() => _isDefaultDialer = isDefault == true);
    } catch (_) {}
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('agent_name', _nameController.text.trim());
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved!'), backgroundColor: Colors.green));
  }

  Future<void> _setDefaultDialer() async {
    try {
      await _callChannel.invokeMethod('requestDefaultDialer');
      await Future.delayed(const Duration(seconds: 2));
      _load();
    } catch (_) {}
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
              hintText: 'Enter your name',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('Save')),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          const Text('Default Phone App', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(_isDefaultDialer ? Icons.check_circle : Icons.cancel,
                  color: _isDefaultDialer ? Colors.green : Colors.grey),
              const SizedBox(width: 8),
              Text(_isDefaultDialer ? 'This app is the default dialer' : 'Not set as default dialer'),
            ],
          ),
          if (!_isDefaultDialer) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _setDefaultDialer,
              icon: const Icon(Icons.phone),
              label: const Text('Set as Default Phone App'),
            ),
          ],
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
