import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/doctor/sign_up_data.dart';

class EmailService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Sends a registration email using the device's email client
  Future<bool> sendSignupEmail(SignupData data) async {
    final emailSubject = 'New Registration Request: ${data.name} - ${data.role}';
    final emailBody = _generateEmailBody(data);

    final emailUri = Uri(
      scheme: 'mailto',
      path: 'longeviva.app@gmail.com',
      query: 'subject=${Uri.encodeComponent(emailSubject)}&body=${Uri.encodeComponent(emailBody)}',
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('Error sending email: $e');
      return false;
    }
  }

  /// Send a custom email
  Future<bool> sendCustomEmail({
    required String to,
    required String subject,
    required String body,
    List<String> cc = const [],
  }) async {
    // For development/testing, use mailto scheme
    // In production, consider using a proper email service API

    String query = 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';

    // Add cc emails if provided
    if (cc.isNotEmpty) {
      query += '&cc=${Uri.encodeComponent(cc.join(','))}';
    }

    final emailUri = Uri(
      scheme: 'mailto',
      path: to,
      query: query,
    );

    try {
      // Store email in Firestore for record-keeping
      await _logEmailToFirestore(to: to, subject: subject, body: body, cc: cc);

      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
        return true;
      } else {
        // Log failure
        await _logEmailToFirestore(
          to: to,
          subject: subject,
          body: body,
          cc: cc,
          status: 'failed',
          error: 'Could not launch email client',
        );
        return false;
      }
    } catch (e) {
      print('Error sending email: $e');

      // Log error
      await _logEmailToFirestore(
        to: to,
        subject: subject,
        body: body,
        cc: cc,
        status: 'failed',
        error: e.toString(),
      );
      return false;
    }
  }

  /// Log email to Firestore for record-keeping
  Future<void> _logEmailToFirestore({
    required String to,
    required String subject,
    required String body,
    List<String> cc = const [],
    String status = 'sent',
    String error = '',
  }) async {
    try {
      await _firestore.collection('email_logs').add({
        'to': to,
        'subject': subject,
        'body': body,
        'cc': cc,
        'status': status,
        'error': error,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error logging email: $e');
    }
  }

  /// Generate the email body with form data including new fields
  String _generateEmailBody(SignupData data) {
    final formatter = DateFormat('yyyy-MM-dd');

    String body = 'Registration Request for Longeviva\n\n';
    body += '=== BASIC INFORMATION ===\n';
    body += 'Role: ${data.role}\n';
    body += 'Name: ${data.name}\n';

    if (data.role == 'DOCTOR') {
      body += 'Surname: ${data.surname}\n';
      body += 'Sex: ${data.sex}\n';
      body += 'Birthdate: ${data.birthdate != null ? formatter.format(data.birthdate!) : "N/A"}\n';
      body += 'VAT Number: ${data.vatNumber}\n';
      body += 'Fiscal Code: ${data.fiscalCode}\n';
    } else {
      body += 'Business Name (Ragione Sociale): ${data.ragioneSociale}\n';
      body += 'Fiscal Code: ${data.fiscalCode}\n';
    }

    body += '\n=== PROFESSIONAL INFORMATION ===\n';
    body += 'Specialty: ${data.specialty}\n';
    body += 'Organization: ${data.organization}\n';
    body += 'City of Work: ${data.cityOfWork}\n';

    body += '\n=== CONTACT INFORMATION ===\n';
    body += 'Phone Number: ${data.phoneNumber}\n';
    body += 'Email: ${data.email}\n';
    body += 'Google Email: ${data.googleEmail}\n';
    body += 'Address: ${data.address}\n';

    body += '\n=== ADDITIONAL INFORMATION ===\n';
    body += 'Languages Spoken: ${data.languagesSpoken.join(", ")}\n';

    body += '\n=== ADMIN ACTION REQUIRED ===\n';
    body += 'Please review and process this registration request in the admin portal.\n';
    body += 'All fields have been validated and the request is ready for approval.\n\n';

    body += 'Thank you.\n';
    body += '-- Longeviva Admin System';

    return body;
  }
}