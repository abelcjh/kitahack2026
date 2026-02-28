import 'dart:async';
import 'dart:collection';
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
  bool _callActive = false;
  final Queue<Uint8List> _pendingChunks = Queue<Uint8List>();

  final _updateController = StreamController<CallAnalysisUpdate>.broadcast();
  Stream<CallAnalysisUpdate> get stream => _updateController.stream;

  StreamSubscription? _nativeSubscription;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  void startListening() {
    _nativeSubscription?.cancel();
    _nativeSubscription = _eventChannel
        .receiveBroadcastStream()
        .listen(_onNativeEvent, onError: (_) {});

    _methodChannel.setMethodCallHandler((call) async {
      if (call.method == 'onPermissionsUpdate') {
        // Handled by PermissionService
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
        break;
      case 'audioChunk':
        final data = event['data'];
        if (data is Uint8List) _enqueueChunk(data);
        break;
      case 'callEnded':
        final data = event['data'];
        if (data is Uint8List) _enqueueChunk(data);
        _onCallEnded();
        break;
    }
  }

  void _onCallStarted(String callerNumber) {
    _accumulatedTranscript = '';
    _currentCallerNumber = callerNumber;
    _scamDetectedDuringCall = false;
    _chunkIndex = 0;
    _processingChunk = false;
    _callActive = true;
    _pendingChunks.clear();
    _push(CallAnalysisState.callStarted);
  }

  // ── Audio chunk queue ─────────────────────────────────────────────────────
  void _enqueueChunk(Uint8List wavBytes) {
    if (!_callActive) return;

    if (_processingChunk) {
      _pendingChunks.addLast(wavBytes);
    } else {
      _processChunk(wavBytes);
    }
  }

  Future<void> _processChunk(Uint8List wavBytes) async {
    if (!_callActive) return;
    _processingChunk = true;

    _chunkIndex++;
    _push(CallAnalysisState.transcribing);

    try {
      final chunkTranscript = await _stt.transcribeAudio(wavBytes);

      if (chunkTranscript.isNotEmpty) {
        _accumulatedTranscript = '$_accumulatedTranscript $chunkTranscript'.trim();
        _push(CallAnalysisState.analyzing);

        if (!_scamDetectedDuringCall) {
          final result = await _gemini.analyzeTranscript(_accumulatedTranscript);

          if (result.isScam) {
            _scamDetectedDuringCall = true;
            _push(CallAnalysisState.scamDetected, result: result);

            await _methodChannel.invokeMethod('scamDetected', {
              'reason': result.reason,
              'number': _currentCallerNumber,
            });

            unawaited(_scamNumberService.addScamNumber(
              _currentCallerNumber,
              result.reason,
            ));

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
        _push(CallAnalysisState.listening);
      }
    } catch (e, stacktrace) {
      print("STT error: $e");
      print(stacktrace);
      _push(CallAnalysisState.listening);
    } finally {
      _processingChunk = false;
      _drainQueue();
    }
  }

  void _drainQueue() {
    if (_pendingChunks.isNotEmpty && !_processingChunk && _callActive) {
      final next = _pendingChunks.removeFirst();
      _processChunk(next);
    }
  }

  void _onCallEnded() {
    _callActive = false;
    _pendingChunks.clear();

    // Push callEnded BEFORE clearing so the UI receives the transcript
    _push(CallAnalysisState.callEnded);

    if (!_scamDetectedDuringCall) {
      _accumulatedTranscript = '';
      _currentCallerNumber = '';
    }
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

void unawaited(Future<void> future) {}
