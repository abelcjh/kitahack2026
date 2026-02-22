import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class ScamNumber {
  final String? id;
  final String phoneNumber;
  final int reportCount;
  final DateTime firstReportedAt;
  final DateTime lastReportedAt;
  final String latestAiReason;
  final List<String> reporters;

  const ScamNumber({
    this.id,
    required this.phoneNumber,
    required this.reportCount,
    required this.firstReportedAt,
    required this.lastReportedAt,
    required this.latestAiReason,
    required this.reporters,
  });

  /// Document ID is SHA-256 hash of the normalized phone number.
  /// This allows O(1) lookups by document ID and protects privacy.
  static String hashNumber(String phoneNumber) {
    final normalized = phoneNumber.replaceAll(RegExp(r'[^+0-9]'), '');
    final bytes = utf8.encode(normalized);
    return sha256.convert(bytes).toString();
  }

  Map<String, dynamic> toFirestore() => {
        'phoneNumber': phoneNumber,
        'reportCount': reportCount,
        'firstReportedAt': FieldValue.serverTimestamp(),
        'lastReportedAt': FieldValue.serverTimestamp(),
        'latestAiReason': latestAiReason,
        'reporters': reporters,
      };

  factory ScamNumber.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ScamNumber(
      id: doc.id,
      phoneNumber: data['phoneNumber'] ?? '',
      reportCount: data['reportCount'] ?? 1,
      firstReportedAt:
          (data['firstReportedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastReportedAt:
          (data['lastReportedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      latestAiReason: data['latestAiReason'] ?? '',
      reporters: List<String>.from(data['reporters'] ?? []),
    );
  }
}
