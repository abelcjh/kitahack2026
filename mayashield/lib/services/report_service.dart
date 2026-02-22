import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/constants.dart';
import '../models/analysis_result.dart';
import '../models/scam_report.dart';

class ReportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _collection =>
      _db.collection(AppConstants.collectionScamReports);

  /// Saves a scam report to Firestore.
  /// Returns the document ID on success.
  Future<String?> reportScam({
    required String transcript,
    required String callerNumber,
    required AnalysisResult result,
    bool pdrmNotified = false,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final report = ScamReport(
        transcript: transcript,
        callerNumber: callerNumber,
        aiVerdict: result.isScam,
        aiReason: result.reason,
        aiConfidence: result.confidence,
        aiIndicators: result.indicators,
        reportedAt: DateTime.now(),
        pdrmNotified: pdrmNotified,
        reporterUid: uid,
      );

      final docRef = await _collection.add(report.toFirestore());
      return docRef.id;
    } catch (_) {
      return null;
    }
  }

  /// Returns recent scam reports for the current user (for history display).
  Future<List<ScamReport>> getMyReports({int limit = 50}) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final snapshot = await _collection
          .where('reporterUid', isEqualTo: uid)
          .orderBy('reportedAt', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs.map(ScamReport.fromFirestore).toList();
    } catch (_) {
      return [];
    }
  }

  /// Opens the system phone dialer with PDRM CCID number pre-filled.
  Future<bool> dialPDRM() async {
    final uri = Uri.parse(AppConstants.pdrmHotline);
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri);
    }
    return false;
  }

  /// Marks a report as PDRM-notified.
  Future<void> markPdrmNotified(String reportId) async {
    try {
      await _collection.doc(reportId).update({'pdrmNotified': true});
    } catch (_) {}
  }
}
