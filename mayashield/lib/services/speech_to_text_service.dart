import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/constants.dart';

class SpeechToTextService {
  /// Transcribes a WAV audio chunk using Google STT V2 Chirp 3.
  /// [wavBytes] must be a valid WAV file (PCM 16kHz mono with header).
  /// Returns the concatenated transcript string, or empty string on failure.
  Future<String> transcribeAudio(Uint8List wavBytes) async {
    if (wavBytes.isEmpty) return '';

    final base64Audio = base64Encode(wavBytes);

    final body = jsonEncode({
      'config': {
        'model': 'chirp_3',
        'languageCodes': AppConstants.sttLanguageCodes,
        'autoDecodingConfig': {},
      },
      'content': base64Audio,
    });

    try {
      final response = await http
          .post(
            Uri.parse(AppConstants.sttEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return _parseTranscript(response.body);
      } else {
        // Fallback: retry with auto language detection
        return await _retryWithAutoLanguage(base64Audio);
      }
    } catch (e) {
      return '';
    }
  }

  String _parseTranscript(String responseBody) {
    try {
      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      return results
          .map((r) {
            final alternatives = r['alternatives'] as List<dynamic>? ?? [];
            if (alternatives.isEmpty) return '';
            return alternatives[0]['transcript'] as String? ?? '';
          })
          .where((t) => t.isNotEmpty)
          .join(' ');
    } catch (_) {
      return '';
    }
  }

  Future<String> _retryWithAutoLanguage(String base64Audio) async {
    try {
      final body = jsonEncode({
        'config': {
          'model': 'chirp_3',
          'languageCodes': ['auto'],
          'autoDecodingConfig': {},
        },
        'content': base64Audio,
      });

      final response = await http
          .post(
            Uri.parse(AppConstants.sttEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return _parseTranscript(response.body);
      }
      return '';
    } catch (_) {
      return '';
    }
  }
}
