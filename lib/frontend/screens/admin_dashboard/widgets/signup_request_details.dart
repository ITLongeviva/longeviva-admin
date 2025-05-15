import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../backend/bloc/signup_request_bloc.dart';
import '../../../../backend/models/signup_request_model.dart';
import '../../../../shared/utils/colors.dart';
import '../../../../shared/utils/context_extensions.dart';

class SignupRequestDetails extends StatefulWidget {
  final SignupRequest request;

  const SignupRequestDetails({Key? key, required this.request}) : super(key: key);

  @override
  State<SignupRequestDetails> createState() => _SignupRequestDetailsState();
}

class _SignupRequestDetailsState extends State<SignupRequestDetails> {
  final TextEditingController _tempPasswordController = TextEditingController();
  bool _passwordVisible = false;

  @override
  void initState() {
    super.initState();
    // Generate a random password on initialization
    _tempPasswordController.text = _generateRandomPassword(10);
  }

  @override
  void dispose() {
    _tempPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.request.role == 'DOCTOR'
                      ? 'Doctor Registration Request'
                      : 'Clinic Registration Request',
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: CustomColors.verdeAbisso,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const Divider(),

            // Request details
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status and date
                    _buildStatusSection(widget.request),

                    const SizedBox(height: 16),

                    // Personal details
                    _buildSection(
                      title: 'Personal Details',
                      icon: Icons.person,
                      children: [
                        _buildDetailRow('Name', widget.request.name),
                        if (widget.request.role == 'DOCTOR')
                          _buildDetailRow('Surname', widget.request.surname),
                        if (widget.request.role == 'DOCTOR') _buildDetailRow('Sex', widget.request.sex),
                        if (widget.request.role == 'DOCTOR' && widget.request.birthdate != null)
                          _buildDetailRow(
                              'Birthdate', DateFormat('yyyy-MM-dd').format(widget.request.birthdate!)),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Professional details
                    _buildSection(
                      title: 'Professional Details',
                      icon: Icons.work,
                      children: [
                        _buildDetailRow('Role', widget.request.role),
                        _buildDetailRow('Specialty', widget.request.specialty),
                        _buildDetailRow('City of Work', widget.request.cityOfWork),
                        if (widget.request.role == 'DOCTOR')
                          _buildDetailRow('VAT Number', widget.request.vatNumber),
                        if (widget.request.role == 'CLINIC')
                          _buildDetailRow('Fiscal Code', widget.request.fiscalCode),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Contact details
                    _buildSection(
                      title: 'Contact Details',
                      icon: Icons.contact_mail,
                      children: [
                        _buildDetailRow('Email', widget.request.email),
                        _buildDetailRow('Google Email', widget.request.googleEmail),
                        _buildDetailRow('Phone', widget.request.phoneNumber),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const Divider(),

            // Action buttons
            if (widget.request.status == 'pending')
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showRejectDialog(context),
                    icon: const Icon(Icons.cancel, color: CustomColors.rossoSimone),
                    label: const Text(
                      'Reject',
                      style: TextStyle(
                        color: CustomColors.rossoSimone,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: CustomColors.rossoSimone),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showApprovalDialog(context),
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: const Text(
                      'Approve',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CustomColors.verdeMare,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection(SignupRequest request) {
    Color statusColor;
    IconData statusIcon;

    switch (request.status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = CustomColors.rossoSimone;
        statusIcon = Icons.cancel;
        break;
      default: // pending
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, color: statusColor, size: 16),
              const SizedBox(width: 4),
              Text(
                request.status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  fontFamily: 'Montserrat',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Text(
          overflow: TextOverflow.ellipsis,
          'Requested on ${DateFormat('MMM d, yyyy').format(request.requestedAt)}',
          style: const TextStyle(
            fontFamily: 'Montserrat',
            color: Colors.grey,
            fontSize: 14,
          )
        ),
        if (request.status == 'approved')
          Expanded(
            child: Text(
              overflow: TextOverflow.ellipsis,
              ' • Approved on ${DateFormat('MMM d, yyyy').format(request.processedAt!)}',
              style: const TextStyle(
                fontFamily: 'Montserrat',
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
        if (request.status == 'rejected')
          Expanded(
            child: Text(
              overflow: TextOverflow.ellipsis,
              ' • Rejected on ${DateFormat('MMM d, yyyy').format(request.processedAt!)}',
              style: const TextStyle(
                fontFamily: 'Montserrat',
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CustomColors.perla.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CustomColors.verdeAbisso.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: CustomColors.verdeAbisso),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: CustomColors.verdeAbisso,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label + ':',
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showApprovalDialog(BuildContext context) {
    // Capture the bloc reference before showing dialog
    final signupRequestBloc = context.read<SignupRequestBloc>();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Approve Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Set a temporary password for the new user:',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tempPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Temporary Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      setState(() {
                        _tempPasswordController.text = _generateRandomPassword(10);
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'The user will be prompted to change this password on first login.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    // Use the captured bloc reference
                    signupRequestBloc.add(
                      ApproveSignupRequestWithPassword(
                        id: widget.request.id,
                        temporaryPassword: _tempPasswordController.text,
                      ),
                    );
                  },
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: const Text(
                    'Approve',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CustomColors.verdeMare,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showRejectDialog(BuildContext context) {
    // Capture the bloc reference before showing dialog
    final signupRequestBloc = context.read<SignupRequestBloc>();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Reject Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Please provide a reason for rejection:'),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Rejection Reason',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    // Use the captured bloc reference
                    signupRequestBloc.add(
                      RejectSignupRequestWithReason(
                        id: widget.request.id,
                        reason: reasonController.text,
                      ),
                    );
                  },
                  icon: const Icon(Icons.cancel, color: CustomColors.rossoSimone),
                  label: const Text(
                    'Reject',
                    style: TextStyle(
                      color: CustomColors.rossoSimone,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: CustomColors.rossoSimone),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // Helper method to generate random password
  String _generateRandomPassword(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
