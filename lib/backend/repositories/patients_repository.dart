import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/patient_model.dart';

class PatientsRepository {
  final FirebaseFirestore _firestore;

  PatientsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<Patient>> loadAll() async {
    final snap = await _firestore.collection('patients').get();
    return snap.docs
        .map((doc) => Patient.fromJson(doc.data(), doc.id))
        .toList();
  }
}
