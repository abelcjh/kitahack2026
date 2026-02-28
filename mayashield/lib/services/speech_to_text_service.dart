import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis_auth/auth_io.dart';
import '../config/constants.dart';

class SpeechToTextService {
  /// Transcribes a WAV audio chunk using Google STT V2 Chirp 3.
  Future<String> transcribeAudio(Uint8List wavBytes) async {
    if (wavBytes.isEmpty) return '';

    final base64Audio = base64Encode(wavBytes);

    // 1. Load the Service Account JSON you just added to the assets folder
    final accountJson = await rootBundle.loadString('assets/kitahack-2026-488510-1741d7599bd5.json'); // Check filename!
    final credentials = ServiceAccountCredentials.fromJson(accountJson);
    
    // 2. Define the exact Cloud security clearance we need
    final scopes = ['https://www.googleapis.com/auth/cloud-platform'];

    // 3. Generate the secure Google Auth Client (Replaces standard http client)
    final authClient = await clientViaServiceAccount(credentials, scopes);

    final body = jsonEncode({
      'config': {
        'model': 'chirp_3',
        'languageCodes': AppConstants.sttLanguageCodes,
        'autoDecodingConfig': {},
      },
      'content': base64Audio,
    });

    try {
      // 4. Send the request using the secure authClient
      final response = await authClient
          .post(
            Uri.parse(AppConstants.sttEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return _parseTranscript(response.body);
      } else {
        // Fallback: retry with auto language detection, passing the secure client
        return await _retryWithAutoLanguage(base64Audio, authClient);
      }
    } catch (e) {
      print('STT V2 Error: $e'); // Helpful for hackathon debugging
      return '';
    } finally {
      // 5. Always close the client to prevent memory leaks during long phone calls
      authClient.close(); 
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

  // Notice we now pass the authClient into the retry function as well
  Future<String> _retryWithAutoLanguage(String base64Audio, AuthClient authClient) async {
    try {
      final body = jsonEncode({
        'config': {
          'model': 'chirp_3',
          'languageCodes': ['auto'],
          'autoDecodingConfig': {},
        },
        'content': base64Audio,
      });

      final response = await authClient
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