class AnalysisResult {
  final bool isScam;
  final int confidence;
  final String reason;
  final List<String> indicators;

  const AnalysisResult({
    required this.isScam,
    required this.confidence,
    required this.reason,
    required this.indicators,
  });

  factory AnalysisResult.safe() => const AnalysisResult(
        isScam: false,
        confidence: 0,
        reason: 'No scam indicators detected.',
        indicators: [],
      );

  factory AnalysisResult.error(String message) => AnalysisResult(
        isScam: false,
        confidence: 0,
        reason: 'Analysis error: $message',
        indicators: [],
      );

  /// Parses Gemini's structured text response.
  /// Expected format:
  ///   VERDICT: SCAM|SAFE
  ///   CONFIDENCE: 0-100
  ///   REASON: <one sentence>
  ///   INDICATORS: <comma-separated list>
  factory AnalysisResult.fromGeminiText(String text) {
    try {
      final lines = text.split('\n').map((l) => l.trim()).toList();

      String verdict = 'SAFE';
      int confidence = 0;
      String reason = 'Unable to parse response.';
      List<String> indicators = [];

      for (final line in lines) {
        if (line.startsWith('VERDICT:')) {
          verdict = line.substring(8).trim().toUpperCase();
        } else if (line.startsWith('CONFIDENCE:')) {
          confidence = int.tryParse(line.substring(11).trim()) ?? 0;
        } else if (line.startsWith('REASON:')) {
          reason = line.substring(7).trim();
        } else if (line.startsWith('INDICATORS:')) {
          final raw = line.substring(11).trim();
          indicators = raw.isEmpty
              ? []
              : raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        }
      }

      return AnalysisResult(
        isScam: verdict == 'SCAM',
        confidence: confidence.clamp(0, 100),
        reason: reason,
        indicators: indicators,
      );
    } catch (_) {
      return AnalysisResult.safe();
    }
  }

  @override
  String toString() =>
      'AnalysisResult(isScam: $isScam, confidence: $confidence, reason: $reason)';
}
