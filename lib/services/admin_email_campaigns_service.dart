import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// One `emailCampaigns/{id}` document (written by Cloud Functions).
class EmailCampaign {
  const EmailCampaign({
    required this.id,
    required this.kind,
    required this.year,
    required this.status,
    required this.sendAt,
    required this.dailyLimit,
    required this.total,
    required this.pending,
    required this.sent,
    required this.skipped,
    required this.failed,
    this.createdAt,
    this.lastRunAt,
  });

  factory EmailCampaign.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final counts = data['counts'] is Map
        ? Map<String, dynamic>.from(data['counts'] as Map)
        : const <String, dynamic>{};
    int count(String key) => (counts[key] as num?)?.toInt() ?? 0;
    DateTime? date(String key) => (data[key] as Timestamp?)?.toDate();
    return EmailCampaign(
      id: doc.id,
      kind: data['kind'] as String? ?? '',
      year: (data['year'] as num?)?.toInt() ?? 0,
      status: data['status'] as String? ?? '',
      sendAt: date('sendAt'),
      dailyLimit: (data['dailyLimit'] as num?)?.toInt() ?? 0,
      total: count('total'),
      pending: count('pending'),
      sent: count('sent'),
      skipped: count('skipped'),
      failed: count('failed'),
      createdAt: date('createdAt'),
      lastRunAt: date('lastRunAt'),
    );
  }

  final String id;
  final String kind;
  final int year;
  final String status;
  final DateTime? sendAt;
  final int dailyLimit;
  final int total;
  final int pending;
  final int sent;
  final int skipped;
  final int failed;
  final DateTime? createdAt;
  final DateTime? lastRunAt;

  bool get isActive => status == 'queued' || status == 'sending';

  /// Share of recipients handled (sent, skipped or failed).
  double get progress => total == 0 ? 1 : (total - pending) / total;
}

/// A recipient that did not get the email, with the reason.
class EmailCampaignRecipientIssue {
  const EmailCampaignRecipientIssue({
    required this.userId,
    required this.status,
    this.reason,
  });

  final String userId;
  final String status;
  final String? reason;
}

/// Admin: queue, test and cancel email campaigns; watch their progress.
class AdminEmailCampaignsService {
  AdminEmailCampaignsService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Stream<List<EmailCampaign>> watchCampaigns() {
    return _firestore
        .collection('emailCampaigns')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs.map(EmailCampaign.fromDoc).toList());
  }

  /// Failed recipients, and any stuck in "sending" (a run died mid-send).
  Future<List<EmailCampaignRecipientIssue>> fetchIssues(
    String campaignId,
  ) async {
    final snap = await _firestore
        .collection('emailCampaigns')
        .doc(campaignId)
        .collection('recipients')
        .where('status', whereIn: const ['failed', 'sending'])
        .limit(100)
        .get();
    return snap.docs
        .map(
          (doc) => EmailCampaignRecipientIssue(
            userId: doc.id,
            status: doc.data()['status'] as String? ?? '',
            reason: doc.data()['reason'] as String?,
          ),
        )
        .toList();
  }

  /// Counts of skipped recipients by reason (opted-out, unverified, ...).
  Future<Map<String, int>> fetchSkipReasons(String campaignId) async {
    final snap = await _firestore
        .collection('emailCampaigns')
        .doc(campaignId)
        .collection('recipients')
        .where('status', isEqualTo: 'skipped')
        .get();
    final reasons = <String, int>{};
    for (final doc in snap.docs) {
      final reason = doc.data()['reason'] as String? ?? 'unknown';
      reasons[reason] = (reasons[reason] ?? 0) + 1;
    }
    return reasons;
  }

  Future<({String campaignId, int total})> createYearReviewCampaign({
    required int year,
    required DateTime sendAt,
    required int dailyLimit,
  }) async {
    final result = await _functions
        .httpsCallable(
          'createYearReviewEmailCampaign',
          options: HttpsCallableOptions(timeout: const Duration(minutes: 5)),
        )
        .call<Map<String, dynamic>>({
          'year': year,
          'sendAt': sendAt.toUtc().toIso8601String(),
          'dailyLimit': dailyLimit,
        });
    final data = Map<String, dynamic>.from(result.data);
    return (
      campaignId: data['campaignId'] as String? ?? '',
      total: (data['total'] as num?)?.toInt() ?? 0,
    );
  }

  /// Sends [previewUserId]'s review (default: yours) to your own address.
  /// Returns a human-readable outcome.
  Future<String> sendYearReviewTest({
    required int year,
    String? previewUserId,
  }) async {
    final result = await _functions
        .httpsCallable('sendYearReviewTestEmail')
        .call<Map<String, dynamic>>({
          'year': year,
          if (previewUserId != null && previewUserId.isNotEmpty)
            'previewUserId': previewUserId,
        });
    final data = Map<String, dynamic>.from(result.data);
    if (data['success'] == true) {
      return 'Test sent to ${data['sentTo']} (${data['locale']})';
    }
    return 'Nothing sent: ${data['reason']}';
  }

  Future<void> cancelCampaign(String campaignId) async {
    await _functions.httpsCallable('cancelEmailCampaign').call<void>({
      'campaignId': campaignId,
    });
  }
}
