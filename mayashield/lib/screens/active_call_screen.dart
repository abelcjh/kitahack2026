import 'package:flutter/material.dart';
import '../services/call_service.dart';
import '../widgets/transcript_card.dart';
import 'result_screen.dart';
import '../services/report_service.dart';

class ActiveCallScreen extends StatefulWidget {
  final CallService callService;

  const ActiveCallScreen({super.key, required this.callService});

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  CallAnalysisUpdate? _latest;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    widget.callService.stream.listen(_onUpdate);
  }

  void _onUpdate(CallAnalysisUpdate update) {
    if (!mounted) return;
    setState(() => _latest = update);

    if (!_navigated &&
        (update.state == CallAnalysisState.callEnded ||
            update.state == CallAnalysisState.scamDetected)) {
      _navigated = true;
      _navigateToResult(update);
    }
  }

  void _navigateToResult(CallAnalysisUpdate update) {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ResultScreen(
        result: update.latestResult,
        transcript: update.accumulatedTranscript,
        callerNumber: update.callerNumber,
        reportService: ReportService(),
        wasAutoDetected: true,
      ),
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String get _statusText {
    switch (_latest?.state) {
      case CallAnalysisState.callStarted:
        return 'Call detected — starting analysis...';
      case CallAnalysisState.listening:
        return 'Listening (chunk ${_latest?.chunkIndex ?? 0})...';
      case CallAnalysisState.transcribing:
        return 'Transcribing audio chunk ${_latest?.chunkIndex ?? 0}...';
      case CallAnalysisState.analyzing:
        return 'Analyzing conversation with Gemini...';
      case CallAnalysisState.scamDetected:
        return 'SCAM DETECTED — alerting you now';
      case CallAnalysisState.callEnded:
        return 'Call ended — preparing results...';
      default:
        return 'Initializing...';
    }
  }

  Color get _statusColor {
    if (_latest?.state == CallAnalysisState.scamDetected) {
      return const Color(0xFFEF5350);
    }
    if (_latest?.state == CallAnalysisState.analyzing) {
      return const Color(0xFFFFA726);
    }
    return const Color(0xFF42A5F5);
  }

  @override
  Widget build(BuildContext context) {
    final callerNumber = _latest?.callerNumber ?? '';
    final transcript = _latest?.accumulatedTranscript ?? '';
    final isScamDetected =
        _latest?.state == CallAnalysisState.scamDetected;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('Active Call Monitor'),
        backgroundColor: const Color(0xFF0D47A1),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Caller number banner
          Container(
            width: double.infinity,
            color: isScamDetected
                ? const Color(0xFFB71C1C)
                : const Color(0xFF1A237E),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Column(
              children: [
                Text(
                  callerNumber.isEmpty ? 'Unknown Number' : callerNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Unsaved number — MayaShield monitoring',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),

          // Pulsing recording indicator
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _pulseController,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isScamDetected
                          ? const Color(0xFFEF5350)
                          : const Color(0xFF66BB6A),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _statusText,
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Live transcript
          Expanded(
            child: SingleChildScrollView(
              child: TranscriptCard(
                transcript: transcript,
                isLive: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
