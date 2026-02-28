import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/analysis_result.dart';
import 'scam_detection_service.dart';
import 'scam_number_service.dart';
import 'report_service.dart';
import 'speech_to_text_service.dart';

/// Possible states of the live call analysis pipeline.
enum CallAnalysisState {
  idle,
  callStarted,
  listening,
  transcribing,
  analyzing,
  scamDetected,
  callEnded,
}

/// Snapshot of live call state -- pushed to UI via [stream].
class CallAnalysisUpdate {
  final CallAnalysisState state;
  final String callerNumber;
  final String accumulatedTranscript;
  final int chunkIndex;
  final AnalysisResult? latestResult;

  const CallAnalysisUpdate({
    required this.state,
    required this.callerNumber,
    required this.accumulatedTranscript,
    required this.chunkIndex,
    this.latestResult,
  });
}

class CallService {
  static const _eventChannel = EventChannel('com.mayashield/audio_stream');
  static const _methodChannel = MethodChannel('com.mayashield/call');

  final SpeechToTextService _stt;
  final ScamDetectionService _gemini;
  final ScamNumberService _scamNumberService;
  final ReportService _reportService;

  CallService({
    required SpeechToTextService stt,
    required ScamDetectionService gemini,
    required ScamNumberService scamNumberService,
    required ReportService reportService,
  })  : _stt = stt,
        _gemini = gemini,
        _scamNumberService = scamNumberService,
        _reportService = reportService;

  // ── State ──────────────────────────────────────────────────────────────────
  String _accumulatedTranscript = '';
  String _currentCallerNumber = '';
  bool _scamDetectedDuringCall = false;
  int _chunkIndex = 0;
  bool _processingChunk = false;

  final _updateController = StreamController<CallAnalysisUpdate>.broadcast();
  Stream<CallAnalysisUpdate> get stream => _updateController.stream;

  StreamSubscription? _nativeSubscription;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Start listening to events from the Android CallRecordingService.
  void startListening() {
    _nativeSubscription?.cancel();
    _nativeSubscription = _eventChannel
        .receiveBroadcastStream()
        .listen(_onNativeEvent, onError: (_) {});

    // Also listen for permission update callbacks from MainActivity.onResume
    _methodChannel.setMethodCallHandler((call) async {
      if (call.method == 'onPermissionsUpdate') {
        // Handled by PermissionService -- ignore here
      }
    });
  }

  void stopListening() {
    _nativeSubscription?.cancel();
    _nativeSubscription = null;
  }

  void dispose() {
    stopListening();
    _updateController.close();
  }

  // ── Event handling ─────────────────────────────────────────────────────────

  void _onNativeEvent(dynamic event) {
    if (event is! Map) return;
    final type = event['type'] as String? ?? '';

    switch (type) {
      case 'callStarted':
        _onCallStarted(event['callerNumber'] as String? ?? '');
      case 'audioChunk':
        final data = event['data'];
        if (data is Uint8List) _onAudioChunk(data);
      case 'callEnded':
        final data = event['data'];
        if (data is Uint8List) _onAudioChunk(data, isFinalChunk: true);
        _onCallEnded();
    }
  }

  void _onCallStarted(String callerNumber) {
    _accumulatedTranscript = '';
    _currentCallerNumber = callerNumber;
    _scamDetectedDuringCall = false;
    _chunkIndex = 0;
    _push(CallAnalysisState.callStarted);
  }

  Future<void> _onAudioChunk(
    Uint8List wavBytes, {
    bool isFinalChunk = false,
  }) async {
    // Queue chunks -- don't process concurrently
    if (_processingChunk && !isFinalChunk) return;
    _processingChunk = true;

    _chunkIndex++;
    _push(CallAnalysisState.transcribing);

    try {
      // 1. Transcribe this chunk
      final chunkTranscript = await _stt.transcribeAudio(wavBytes);

      if (chunkTranscript.isNotEmpty) {
        // 2. Append to full context (Gemini always sees the complete conversation)
        _accumulatedTranscript =
            '$_accumulatedTranscript $chunkTranscript'.trim();
        _push(CallAnalysisState.analyzing);

        // 3. Analyze full accumulated transcript (skip if scam already detected)
        if (!_scamDetectedDuringCall) {
          final result =
              await _gemini.analyzeTranscript(_accumulatedTranscript);

          if (result.isScam) {
            _scamDetectedDuringCall = true;
            _push(CallAnalysisState.scamDetected, result: result);

            // 4a. Trigger native overlay
            await _methodChannel.invokeMethod('scamDetected', {
              'reason': result.reason,
              'number': _currentCallerNumber,
            });

            // 4b. Add number to community scam DB (fire-and-forget)
            unawaited(_scamNumberService.addScamNumber(
              _currentCallerNumber,
              result.reason,
            ));

            // 4c. Save full report to Firestore
            unawaited(_reportService.reportScam(
              transcript: _accumulatedTranscript,
              callerNumber: _currentCallerNumber,
              result: result,
            ));
          } else {
            _push(CallAnalysisState.listening);
          }
        }
      } else {
        // If Google returns empty string but no error
        print("⚠️ STT SUCCESS, BUT TRANSCRIPT WAS EMPTY.");
        _push(CallAnalysisState.listening);
      }
    } catch (e, stacktrace) {
      // 🚨 WE UN-SILENCED THE ERROR!
      print("🚨 STT CRASHED: $e");
      print(stacktrace);
      _push(CallAnalysisState.listening);
    } finally {
      _processingChunk = false;
    }

  void _onCallEnded() {
    if (!_scamDetectedDuringCall) {
      // SAFE: discard everything -- no data stored
      _accumulatedTranscript = '';
      _currentCallerNumber = '';
    }
    _push(CallAnalysisState.callEnded);
  }

  void _push(CallAnalysisState state, {AnalysisResult? result}) {
    if (_updateController.isClosed) return;
    _updateController.add(CallAnalysisUpdate(
      state: state,
      callerNumber: _currentCallerNumber,
      accumulatedTranscript: _accumulatedTranscript,
      chunkIndex: _chunkIndex,
      latestResult: result,
    ));
  }

  // ── Permission helpers ─────────────────────────────────────────────────────

  Future<bool> hasOverlayPermission() async {
    return await Permission.systemAlertWindow.isGranted;
  }

  Future<void> requestOverlayPermission() async {
    final status = await Permission.systemAlertWindow.status;
    if (!status.isGranted) {
      // This physically opens the "Draw over other apps" Android settings screen
      await Permission.systemAlertWindow.request();
    }
  }

  Future<bool> isCallScreeningActive() async {
    try {
      return await _methodChannel.invokeMethod<bool>('isCallScreeningRoleActive') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestCallScreeningRole() async {
    try {
      await _methodChannel.invokeMethod('requestCallScreeningRole');
    } catch (_) {}
  }

  // ── Getters for UI ─────────────────────────────────────────────────────────
  String get accumulatedTranscript => _accumulatedTranscript;
  String get currentCallerNumber => _currentCallerNumber;
  bool get scamDetected => _scamDetectedDuringCall;
}

// Suppress "unawaited_futures" for fire-and-forget calls
void unawaited(Future<void> future) {}
