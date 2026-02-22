import 'package:flutter/material.dart';
import '../models/analysis_result.dart';
import '../services/report_service.dart';
import '../widgets/verdict_card.dart';
import '../widgets/transcript_card.dart';

class ResultScreen extends StatefulWidget {
  final AnalysisResult? result;
  final String transcript;
  final String callerNumber;
  final ReportService reportService;
  final bool wasAutoDetected;

  const ResultScreen({
    super.key,
    required this.result,
    required this.transcript,
    required this.callerNumber,
    required this.reportService,
    this.wasAutoDetected = false,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _reportSaved = false;
  bool _isSaving = false;
  bool _pdrmDialed = false;
  String? _savedReportId;

  AnalysisResult get _result =>
      widget.result ?? AnalysisResult.safe();

  @override
  void initState() {
    super.initState();
    // Auto-detected scam reports are saved by CallService mid-call
    if (widget.wasAutoDetected && _result.isScam) {
      _reportSaved = true;
    }
  }

  Future<void> _saveReport() async {
    if (_reportSaved) return;
    setState(() => _isSaving = true);
    try {
      final id = await widget.reportService.reportScam(
        transcript: widget.transcript,
        callerNumber: widget.callerNumber,
        result: _result,
      );
      setState(() {
        _savedReportId = id;
        _reportSaved = true;
        _isSaving = false;
      });
      _showSnack('Report saved to community database');
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnack('Failed to save report');
    }
  }

  Future<void> _dialPDRM() async {
    final success = await widget.reportService.dialPDRM();
    if (success) {
      setState(() => _pdrmDialed = true);
      if (_savedReportId != null) {
        await widget.reportService.markPdrmNotified(_savedReportId!);
      }
    } else {
      _showSnack('Could not open phone dialer');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isScam = _result.isScam;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: Text(isScam ? 'Scam Detected' : 'Call Safe'),
        backgroundColor:
            isScam ? const Color(0xFF7F0000) : const Color(0xFF0D47A1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context)
              .popUntil((route) => route.isFirst),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Verdict card
            VerdictCard(result: _result, callerNumber: widget.callerNumber),

            // Transcript
            if (widget.transcript.isNotEmpty)
              TranscriptCard(transcript: widget.transcript),

            const SizedBox(height: 16),

            if (isScam) ...[
              // Auto-save notice or manual save button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _reportSaved
                    ? _ReportSavedBadge(wasAuto: widget.wasAutoDetected)
                    : _SaveReportButton(
                        isSaving: _isSaving,
                        onSave: _saveReport,
                      ),
              ),

              const SizedBox(height: 12),

              // Call PDRM button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _PdrmButton(
                  dialed: _pdrmDialed,
                  onDial: _dialPDRM,
                ),
              ),

              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'PDRM CCID Scam Response Centre: 03-2610 1559',
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
            ] else ...[
              // Safe call -- nothing stored
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B5E20).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock, color: Color(0xFF66BB6A), size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No data stored. MayaShield only keeps records of confirmed scam calls.',
                          style: TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _ReportSavedBadge extends StatelessWidget {
  final bool wasAuto;
  const _ReportSavedBadge({required this.wasAuto});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B5E20).withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 16),
          const SizedBox(width: 8),
          Text(
            wasAuto
                ? 'Number added to community scam database automatically'
                : 'Report saved to community database',
            style:
                const TextStyle(color: Color(0xFF81C784), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _SaveReportButton extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onSave;
  const _SaveReportButton({required this.isSaving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isSaving ? null : onSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1565C0),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: isSaving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.flag, color: Colors.white),
        label: Text(
          isSaving ? 'Saving...' : 'Report to Community',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _PdrmButton extends StatelessWidget {
  final bool dialed;
  final VoidCallback onDial;
  const _PdrmButton({required this.dialed, required this.onDial});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: dialed ? null : onDial,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              dialed ? Colors.grey[800] : const Color(0xFFC62828),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Icon(
          dialed ? Icons.check : Icons.phone,
          color: Colors.white,
        ),
        label: Text(
          dialed ? 'PDRM Dialed' : 'Call PDRM (03-2610 1559)',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
