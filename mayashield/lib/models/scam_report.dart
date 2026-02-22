import 'package:cloud_firestore/cloud_firestore.dart';

class ScamReport {
  final String? id;
  final String transcript;
  final String callerNumber;
  final bool aiVerdict;
  final String aiReason;
  final int aiConfidence;
  final List<String> aiIndicators;
  final DateTime reportedAt;
  final bool pdrmNotified;
  final String reporterUid;

  const ScamReport({
    this.id,
    required this.transcript,
    required this.callerNumber,
    required this.aiVerdict,
    required this.aiReason,
    required this.aiConfidence,
    required this.aiIndicators,
    required this.reportedAt,
    this.pdrmNotified = false,
    required this.reporterUid,
  });

  Map<String, dynamic> toFirestore() => {
        'transcript': transcript,
        'callerNumber': callerNumber,
        'aiVerdict': aiVerdict ? 'SCAM' : 'SAFE',
        'aiReason': aiReason,
        'aiConfidence': aiConfidence,
        'aiIndicators': aiIndicators,
        'reportedAt': FieldValue.serverTimestamp(),
        'pdrmNotified': pdrmNotified,
        'reporterUid': reporterUid,
        'verified': false,
      };

  factory ScamReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ScamReport(
      id: doc.id,
      transcript: data['transcript'] ?? '',
      callerNumber: data['callerNumber'] ?? '',
      aiVerdict: data['aiVerdict'] == 'SCAM',
      aiReason: data['aiReason'] ?? '',
      aiConfidence: data['aiConfidence'] ?? 0,
      aiIndicators: List<String>.from(data['aiIndicators'] ?? []),
      reportedAt: (data['reportedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      pdrmNotified: data['pdrmNotified'] ?? false,
      reporterUid: data['reporterUid'] ?? '',
    );
  }
}
