class AppConstants {
  // ─── Google Cloud STT V2 ───────────────────────────────────────────────────
  // Note: STT V2 (Chirp 3) authenticates via the Service Account JSON in /assets
  static const String googleCloudProjectId = 'GCP_PROJECT_ID';

  // Chirp 3 is GA in "us" and "eu". Use "asia-southeast1" for lower latency
  // (Preview status -- may have lower reliability).
  static const String sttRegion = 'asia-southeast1';

  // ─── STT Endpoint ─────────────────────────────────────────────────────────
  static String get sttEndpoint =>
      'https://$sttRegion-speech.googleapis.com/v2'
      '/projects/$googleCloudProjectId'
      '/locations/$sttRegion'
      '/recognizers/_:recognize';

  // ─── Gemini model via firebase_ai ─────────────────────────────────────────
  // firebase_vertexai is deprecated -- use firebase_ai
  static const String geminiModel = 'gemini-2.5-flash';

  // ─── PDRM CCID Scam Response Centre ───────────────────────────────────────
  static const String pdrmHotline = 'tel:0326101559';
  static const String pdrmHotlineDisplay = '03-2610 1559';

  // ─── Firestore collections ─────────────────────────────────────────────────
  static const String collectionScamReports = 'scam_reports';
  static const String collectionScamNumbers = 'scam_numbers';

  // ─── Recording settings ───────────────────────────────────────────────────
  // Duration in seconds for each audio chunk sent to STT
  static const int chunkIntervalSeconds = 15;

  // ─── Cache sync interval ──────────────────────────────────────────────────
  static const Duration cacheRefreshInterval = Duration(minutes: 30);

  // ─── STT language codes ───────────────────────────────────────────────────
  // ms-MY is in Preview for Chirp 3. Set to ["auto"] if quality is poor.
  static const List<String> sttLanguageCodes = ['en-US', 'ms-MY'];
}
