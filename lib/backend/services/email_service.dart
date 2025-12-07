import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:emailjs/emailjs.dart' as emailjs;

import '../../shared/config/environment_config.dart';
import '../models/doctor/sign_up_data.dart';

class EmailService {
  FirebaseFirestore get _firestore => EnvironmentConfig().getFirestore();

  // EmailJS Configuration
  static const String _serviceId = 'service_a9k4uio';
  static const String _signupTemplateId = 'template_x7argil';
  static const String _publicKey = 'I1qNXHBqxLLhqP7MI';
  static const String _privateKey = '2qu3z-kwSpKR73EBrA4H9';

  // Placeholder image for professional photo
  static const String _defaultPhotoUrl = 'https://res.cloudinary.com/dddzqfyab/image/upload/v1765109472/longeviva_logo_no_text_gnm4kw.svg';

  /// Sends a registration email using EmailJS
  Future<bool> sendSignupEmail(SignupData data) async {
    final emailSubject = 'Richiesta di registrazione per Longeviva!';

    try {
      // Prepare template parameters for the HTML email template
      final templateParams = {
        'to_email': 'info@longeviva.it',
        'subject': emailSubject,
        'professional_photo_url': _defaultPhotoUrl, // Using placeholder for now
        'professional_role': data.roles.join(", "),
        'professional_name': '${data.name} ${data.surname}',
        'tax_code': data.fiscalCode,
        'specialization': data.specialty ?? data.areaOfInterest ?? 'N/A',
        'phone_number': data.phoneNumber,
        'city': data.cityOfWork,
        'professional_email': data.email,
        'timestamp': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      };

      // Send email via EmailJS
      await emailjs.send(
        _serviceId,
        _signupTemplateId,
        templateParams,
        const emailjs.Options(
          publicKey: _publicKey,
          privateKey: _privateKey,
          limitRate: emailjs.LimitRate(
            id: 'signup_form',
            throttle: 10000, // 10 seconds between submissions
          ),
        ),
      );

      // Log successful email to Firestore
      await _logEmailToFirestore(
        to: 'info@longeviva.it',
        subject: emailSubject,
        body: _generateEmailBodyForLog(data),
        status: 'sent',
      );

      print('Signup email sent successfully via EmailJS');
      return true;

    } catch (error) {
      print('Error sending signup email: $error');

      // Handle EmailJS specific errors
      if (error is emailjs.EmailJSResponseStatus) {
        print('EmailJS error code: ${error.status}');
        print('EmailJS error text: ${error.text}');
      }

      // Log failed email attempt
      await _logEmailToFirestore(
        to: 'info@longeviva.it',
        subject: emailSubject,
        body: _generateEmailBodyForLog(data),
        status: 'failed',
        error: error.toString(),
      );

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
    try {
      // Note: For custom emails, you would need a different EmailJS template
      // For now, we'll log this as not implemented
      print('Custom email feature requires a separate EmailJS template');

      // Store email in Firestore for record-keeping
      await _logEmailToFirestore(
        to: to,
        subject: subject,
        body: body,
        cc: cc,
        status: 'pending',
        error: 'Custom email template not configured',
      );

      return false;

    } catch (error) {
      print('Error sending custom email: $error');

      // Log error
      await _logEmailToFirestore(
        to: to,
        subject: subject,
        body: body,
        cc: cc,
        status: 'failed',
        error: error.toString(),
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
        'service': 'emailjs', // Track which service was used
      });
    } catch (e) {
      print('Error logging email: $e');
    }
  }

  /// Generate the email body for logging purposes (not for the email itself)
  String _generateEmailBodyForLog(SignupData data) {
    final formatter = DateFormat('yyyy-MM-dd');

    String body = 'Registration Request for Longeviva\n\n';
    body += '=== BASIC INFORMATION ===\n';
    body += 'Roles: ${data.roles.join(", ")}\n';
    body += 'Name: ${data.name} ${data.surname}\n';
    body += 'Sex: ${data.sex}\n';
    body += 'Birthdate: ${data.birthdate != null ? formatter.format(data.birthdate!) : "N/A"}\n';
    body += 'VAT Number: ${data.vatNumber}\n';
    body += 'Fiscal Code: ${data.fiscalCode}\n';

    body += '\n=== PROFESSIONAL INFORMATION ===\n';
    body += 'Specialty: ${data.specialty ?? "N/A"}\n';
    body += 'Area of Interest: ${data.areaOfInterest ?? "N/A"}\n';
    body += 'City of Work: ${data.cityOfWork}\n';
    body += 'Country of Work: ${data.countryOfWork}\n';
    body += 'Hourly Fees: €${data.hourlyFees.toStringAsFixed(2)}\n';

    if (data.numero_iscrizione_albo != null) {
      body += 'Professional Registration Number (Albo): ${data.numero_iscrizione_albo}\n';
    }
    if (data.numero_iscrizione_ente != null) {
      body += 'Professional Registration Number (Ente): ${data.numero_iscrizione_ente}\n';
    }
    if (data.issuer.isNotEmpty) {
      body += 'Issuer: ${data.issuer}\n';
    }

    body += '\n=== CONTACT INFORMATION ===\n';
    body += 'Phone Number: ${data.phoneNumber}\n';
    body += 'Email: ${data.email}\n';
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