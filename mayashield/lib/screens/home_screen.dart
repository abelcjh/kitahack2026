import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../services/call_service.dart';
import '../services/scam_number_service.dart';
import '../services/speech_to_text_service.dart';
import '../services/scam_detection_service.dart';
import '../services/report_service.dart';
import '../widgets/service_status_indicator.dart';
import 'active_call_screen.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final CallService _callService;
  late final ScamNumberService _scamNumberService;
  late final AudioRecorder _recorder;
  StreamSubscription<CallAnalysisUpdate>? _callSubscription;
  bool _activeCallScreenVisible = false;

  bool _isCallScreeningActive = false;
  bool _hasOverlayPermission = false;
  int _communityScamCount = 0;
  bool _isRecording = false;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _scamNumberService = ScamNumberService();
    _recorder = AudioRecorder();

    _callService = CallService(
      stt: SpeechToTextService(),
      gemini: ScamDetectionService(),
      scamNumberService: _scamNumberService,
      reportService: ReportService(),
    );

    _callService.startListening();
    _callSubscription = _callService.stream.listen(_onCallUpdate);

    _loadState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadState();
  }

  Future<void> _loadState() async {
    final screening = await _callService.isCallScreeningActive();
    final overlay = await _callService.hasOverlayPermission();
    final count = await _scamNumberService.getScamStats();
    if (mounted) {
      setState(() {
        _isCallScreeningActive = screening;
        _hasOverlayPermission = overlay;
        _communityScamCount = count;
      });
    }
  }

  void _onCallUpdate(CallAnalysisUpdate update) {
    if (!mounted) return;

    if (update.state == CallAnalysisState.callEnded ||
        update.state == CallAnalysisState.idle) {
      _activeCallScreenVisible = false;
      return;
    }

    if (!_activeCallScreenVisible &&
        (update.state == CallAnalysisState.callStarted ||
            update.state == CallAnalysisState.listening ||
            update.state == CallAnalysisState.transcribing ||
            update.state == CallAnalysisState.analyzing)) {
      _activeCallScreenVisible = true;
      Navigator.of(context)
          .push(MaterialPageRoute(
            builder: (_) => ActiveCallScreen(callService: _callService),
          ))
          .then((_) => _activeCallScreenVisible = false);
    }
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _callService.dispose();
    _recorder.dispose();
    super.dispose();
  }

  // ── Manual record (iOS + testing) ─────────────────────────────────────────

  Future<void> _toggleManualRecord() async {
    if (_isRecording) {
      await _stopManualRecord();
    } else {
      await _startManualRecord();
    }
  }

  Future<void> _startManualRecord() async {
    final granted = await Permission.microphone.request().isGranted;
    if (!granted) {
      _showSnack('Microphone permission required');
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/manual_record_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
      path: path,
    );
    setState(() => _isRecording = true);
  }

  Future<void> _stopManualRecord() async {
    final path = await _recorder.stop();
    setState(() => _isRecording = false);
    if (path != null) await _analyzeFile(path);
  }

  Future<void> _pickAndAnalyze() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav', 'mp3', 'm4a', 'ogg', 'flac'],
    );
    if (result == null || result.files.single.path == null) return;
    await _analyzeFile(result.files.single.path!);
  }

  Future<void> _analyzeFile(String path) async {
    setState(() => _isAnalyzing = true);
    try {
      final bytes = await File(path).readAsBytes();
      final transcript = await SpeechToTextService().transcribeAudio(bytes);
      final analysis = await ScamDetectionService().analyzeTranscript(transcript);

      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ResultScreen(
          result: analysis,
          transcript: transcript,
          callerNumber: 'Manual Recording',
          reportService: ReportService(),
        ),
      ));
    } catch (e) {
      _showSnack('Analysis failed: $e');
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.shield, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            const Text('MayaShield',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: const Color(0xFF0D47A1),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadState,
            tooltip: 'Refresh status',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadState,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Service status card
              ServiceStatusIndicator(
                isCallScreeningActive: _isCallScreeningActive,
                hasOverlayPermission: _hasOverlayPermission,
                onEnableCallScreening: _callService.requestCallScreeningRole,
                onEnableOverlay: _callService.requestOverlayPermission,
              ),

              // Community stats
              _CommunityStatsCard(count: _communityScamCount),

              // Manual record section header
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'MANUAL ANALYSIS',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // Manual record / upload buttons
              if (_isAnalyzing)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: Color(0xFF42A5F5)),
                        SizedBox(height: 12),
                        Text('Analyzing audio...',
                            style: TextStyle(color: Colors.white54)),
                      ],
                    ),
                  ),
                )
              else
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: _isRecording ? Icons.stop : Icons.mic,
                          label: _isRecording ? 'Stop Recording' : 'Record',
                          color: _isRecording
                              ? const Color(0xFFEF5350)
                              : const Color(0xFF1565C0),
                          onTap: _toggleManualRecord,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.upload_file,
                          label: 'Upload Audio',
                          color: const Color(0xFF37474F),
                          onTap: _pickAndAnalyze,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // iOS notice
              if (!Platform.isAndroid)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _IosNoticeCard(),
                ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommunityStatsCard extends StatelessWidget {
  final int count;
  const _CommunityStatsCard({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A237E).withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.groups, color: Color(0xFF42A5F5), size: 32),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Community-reported scam numbers',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _IosNoticeCard extends StatelessWidget {
  const _IosNoticeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF37474F),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.white54, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Automatic call screening is not available on iOS. '
              'Use Record or Upload to analyze calls manually.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
