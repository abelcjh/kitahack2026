import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../config/constants.dart';
import '../models/scam_number.dart';

class ScamNumberService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _methodChannel = MethodChannel('com.mayashield/call');

  DateTime? _lastSync;

  CollectionReference get _collection =>
      _db.collection(AppConstants.collectionScamNumbers);

  /// Fetches all known scam numbers from Firestore and pushes them
  /// to the Android native SharedPreferences cache.
  Future<void> syncToLocalCache() async {
    try {
      final snapshot = await _collection
          .orderBy('lastReportedAt', descending: true)
          .limit(5000)
          .get();

      final numbers = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['phoneNumber'] as String? ?? '';
          })
          .where((n) => n.isNotEmpty)
          .toList();

      await _methodChannel.invokeMethod('updateScamCache', {'numbers': numbers});
      _lastSync = DateTime.now();
    } catch (_) {
      // Silent fail -- app still works, just won't have latest community data
    }
  }

  bool get needsSync =>
      _lastSync == null ||
      DateTime.now().difference(_lastSync!) > AppConstants.cacheRefreshInterval;

  /// Adds or updates a scam number in Firestore.
  /// Increments reportCount if the number already exists.
  Future<void> addScamNumber(String phoneNumber, String aiReason) async {
    if (phoneNumber.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final docId = ScamNumber.hashNumber(phoneNumber);
    final docRef = _collection.doc(docId);

    try {
      await _db.runTransaction((tx) async {
        final snapshot = await tx.get(docRef);
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          final reporters = List<String>.from(data['reporters'] ?? []);
          if (!reporters.contains(uid)) reporters.add(uid);
          tx.update(docRef, {
            'reportCount': FieldValue.increment(1),
            'lastReportedAt': FieldValue.serverTimestamp(),
            'latestAiReason': aiReason,
            'reporters': reporters,
          });
        } else {
          tx.set(docRef, {
            'phoneNumber': phoneNumber,
            'reportCount': 1,
            'firstReportedAt': FieldValue.serverTimestamp(),
            'lastReportedAt': FieldValue.serverTimestamp(),
            'latestAiReason': aiReason,
            'reporters': [uid],
          });
        }
      });

      // Also update native cache immediately
      await _methodChannel
          .invokeMethod('addScamNumber', {'number': phoneNumber});
    } catch (_) {
      // Rethrow so CallService can handle
      rethrow;
    }
  }

  /// Returns the total number of community-identified scam numbers.
  Future<int> getScamStats() async {
    try {
      // Use a count query for efficiency
      final snapshot = await _collection.count().get();
      return snapshot.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Returns recently reported scam numbers for the community feed.
  Future<List<ScamNumber>> getRecentScamNumbers({int limit = 20}) async {
    try {
      final snapshot = await _collection
          .orderBy('lastReportedAt', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs.map(ScamNumber.fromFirestore).toList();
    } catch (_) {
      return [];
    }
  }
}
