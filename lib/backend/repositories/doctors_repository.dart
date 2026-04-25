import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/doctor/doctor_model.dart';

class DoctorsRepository {
  final FirebaseFirestore _firestore;

  DoctorsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<Doctor>> loadAll() async {
    final snap = await _firestore.collection('doctors').get();
    return snap.docs
        .map((doc) => Doctor.fromJson({'id': doc.id, ...doc.data()}))
        .toList();
  }
}
