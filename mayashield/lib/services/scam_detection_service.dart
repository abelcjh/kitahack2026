import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/constants.dart';
import '../models/analysis_result.dart';

class ScamDetectionService {
  late final GenerativeModel _model;

  ScamDetectionService() {
    _model = FirebaseAI.googleAI(auth: FirebaseAuth.instance)
        .generativeModel(model: AppConstants.geminiModel);
  }

  /// Analyzes the full accumulated transcript for Malaysian scam patterns.
  /// Gemini receives the ENTIRE conversation history on every call,
  /// enabling detection of escalation patterns that span multiple chunks.
  Future<AnalysisResult> analyzeTranscript(String accumulatedTranscript) async {
    if (accumulatedTranscript.trim().isEmpty) {
      return AnalysisResult.safe();
    }

    final prompt = _buildPrompt(accumulatedTranscript);

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';
      if (text.isEmpty) return AnalysisResult.safe();
      return AnalysisResult.fromGeminiText(text);
    } catch (e) {
      return AnalysisResult.error(e.toString());
    }
  }

  String _buildPrompt(String transcript) => '''
You are MayaShield, an expert Malaysian voice scam detection AI.

Analyze the following phone call transcript for scam activity commonly found in Malaysia.

SCAM PATTERNS TO DETECT:
1. Authority impersonation: LHDN (Inland Revenue Board), PDRM (Police), Bank Negara Malaysia, Maybank, CIMB, Public Bank, Pos Malaysia, MCMC, EPF/KWSP, SOCSO
2. Threats and urgency: arrest warrants, frozen accounts, legal action, fines, deportation
3. Financial demands: wire transfer, Touch 'n Go, DuitNow, Boost, online banking transfers
4. OTP/TAC/PIN requests: asking for one-time passwords, TAC codes, banking PINs
5. Personal data fishing: IC number, bank account, credit card details
6. Emotional manipulation: "your family member is in hospital/arrested", "you have a parcel issue"
7. Manglish/Malaysian patterns: "Encik/Cik, ini panggilan penting", mixing BM/English to sound official
8. Spoofed numbers or claims of calling from official hotlines

TRANSCRIPT:
"""
$transcript
"""

Respond in EXACTLY this format (no extra text before or after):
VERDICT: SCAM or SAFE
CONFIDENCE: 0-100
REASON: One sentence explaining the primary indicator
INDICATORS: comma-separated list of detected patterns (empty if SAFE)

If the transcript is too short to make a determination, respond with SAFE and confidence 10.
If no clear scam indicators exist, respond SAFE.
Only respond SCAM if you are reasonably confident (confidence > 60).
''';
}
