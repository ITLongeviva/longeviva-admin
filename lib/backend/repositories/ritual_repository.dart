import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ritual_model.dart';

class RitualRepository {
  final FirebaseFirestore _firestore;

  RitualRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<Ritual>> getAllRituals() async {
    final snapshot = await _firestore
        .collection('rituals')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Ritual.fromJson(doc.data(), doc.id))
        .toList();
  }
}
