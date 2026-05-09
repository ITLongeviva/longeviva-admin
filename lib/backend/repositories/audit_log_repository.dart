import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/config/environment_config.dart';
import '../../shared/utils/error_handler.dart';
import '../models/admin_action_model.dart';

class AuditLogRepository {
  final FirebaseFirestore _firestore;
  static const String _collectionPath = 'admin_actions';

  AuditLogRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? EnvironmentConfig().getFirestore();

  Future<void> logAction({
    required String adminEmail,
    required String adminName,
    required String action,
    String? requestId,
    String? requestName,
    String? notes,
    int? batchCount,
  }) async {
    try {
      await _firestore.collection(_collectionPath).add({
        'adminEmail': adminEmail,
        'adminName': adminName,
        'action': action,
        'requestId': requestId,
        'requestName': requestName,
        'notes': notes,
        'timestamp': FieldValue.serverTimestamp(),
        'batchCount': batchCount,
      });
    } catch (e) {
      ErrorHandler.logError('Error logging admin action', e);
    }
  }

  Future<List<AdminAction>> getRecentActions({int limit = 30}) async {
    try {
      final snap = await _firestore
          .collection(_collectionPath)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map((doc) => AdminAction.fromJson(doc.data(), doc.id)).toList();
    } catch (e) {
      ErrorHandler.logError('Error fetching audit log', e);
      return [];
    }
  }
}
