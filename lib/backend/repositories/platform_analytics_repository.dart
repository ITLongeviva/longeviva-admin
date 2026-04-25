import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/doctor/doctor_model.dart';
import '../models/signup_request_model.dart';

class PlatformAnalyticsData {
  final List<Doctor> doctors;
  final List<SignupRequest> requests;

  const PlatformAnalyticsData({
    required this.doctors,
    required this.requests,
  });
}

class PlatformAnalyticsRepository {
  final FirebaseFirestore _firestore;

  PlatformAnalyticsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<PlatformAnalyticsData> loadAll() async {
    final results = await Future.wait([
      _firestore.collection('doctors').get(),
      _firestore.collection('signup_requests').get(),
    ]);

    final doctors = results[0].docs.map((doc) {
      return Doctor.fromJson({'id': doc.id, ...doc.data()});
    }).toList();

    final requests = results[1].docs.map((doc) {
      return SignupRequest.fromJson(doc.data(), doc.id);
    }).toList();

    return PlatformAnalyticsData(doctors: doctors, requests: requests);
  }
}
