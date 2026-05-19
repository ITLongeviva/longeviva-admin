import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAction {
  final String id;
  final String adminEmail;
  final String adminName;
  final String action; // 'approve' | 'reject' | 'batch_approve' | 'batch_reject'
  final String? requestId;
  final String? requestName;
  final String? notes;
  final DateTime timestamp;
  final int? batchCount;

  AdminAction({
    required this.id,
    required this.adminEmail,
    required this.adminName,
    required this.action,
    this.requestId,
    this.requestName,
    this.notes,
    required this.timestamp,
    this.batchCount,
  });

  factory AdminAction.fromJson(Map<String, dynamic> json, String docId) {
    DateTime ts = DateTime.now();
    final raw = json['timestamp'];
    if (raw is Timestamp) ts = raw.toDate();
    else if (raw is String) ts = DateTime.tryParse(raw) ?? ts;

    return AdminAction(
      id: docId,
      adminEmail: json['adminEmail'] ?? '',
      adminName: json['adminName'] ?? '',
      action: json['action'] ?? '',
      requestId: json['requestId'],
      requestName: json['requestName'],
      notes: json['notes'],
      timestamp: ts,
      batchCount: json['batchCount'],
    );
  }

  Map<String, dynamic> toJson() => {
    'adminEmail': adminEmail,
    'adminName': adminName,
    'action': action,
    'requestId': requestId,
    'requestName': requestName,
    'notes': notes,
    'timestamp': FieldValue.serverTimestamp(),
    'batchCount': batchCount,
  };
}
