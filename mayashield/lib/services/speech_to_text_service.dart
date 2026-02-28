import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis_auth/auth_io.dart';
import '../config/constants.dart';

class SpeechToTextService {
  AutoRefreshingAuthClient? _cachedClient;

  Future<AutoRefreshingAuthClient> _getAuthClient() async {
    if (_cachedClient != null) return _cachedClient!;

    final accountJson = await rootBundle.loadString(
      'assets/kitahack-2026-488510-1741d7599bd5.json',
    );
    final credentials = ServiceAccountCredentials.fromJson(accountJson);
    final scopes = ['https://www.googleapis.com/auth/cloud-platform'];

    _cachedClient = await clientViaServiceAccount(credentials, scopes);
    return _cachedClient!;
  }

  Future<String> transcribeAudio(Uint8List wavBytes) async {
    if (wavBytes.isEmpty) return '';

    final base64Audio = base64Encode(wavBytes);
    final authClient = await _getAuthClient();

    final body = jsonEncode({
      'config': {
        'model': 'chirp_3',
        'languageCodes': AppConstants.sttLanguageCodes,
        'autoDecodingConfig': {},
      },
      'content': base64Audio,
    });

    try {
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
        return await _retryWithAutoLanguage(base64Audio, authClient);
      }
    } catch (e) {
      print('STT V2 Error: $e');
      _cachedClient?.close();
      _cachedClient = null;
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

  Future<String> _retryWithAutoLanguage(
    String base64Audio,
    AutoRefreshingAuthClient authClient,
  ) async {
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

  void dispose() {
    _cachedClient?.close();
    _cachedClient = null;
  }
}
