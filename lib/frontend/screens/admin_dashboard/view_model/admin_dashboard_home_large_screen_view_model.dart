import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../shared/utils/colors.dart';
import '../../../../backend/bloc/admin_bloc.dart';
import '../../../../backend/bloc/audit_log_bloc.dart';
import '../../../../backend/bloc/signup_request_bloc.dart';
import '../../../../backend/models/admin_action_model.dart';
import '../../../../backend/models/signup_request_model.dart';

class AdminDashboardHomeLargeScreenViewModel extends StatelessWidget {
  const AdminDashboardHomeLargeScreenViewModel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminOperationsBloc, AdminOperationsState>(
      builder: (context, adminState) {
        return BlocBuilder<SignupRequestBloc, SignupRequestState>(
          builder: (context, signupState) {
            int totalUsers = 0;
            int doctorCount = 0;
            int patientCount = 0;
            if (adminState is AllUsersLoaded) {
              totalUsers = adminState.users.length;
              doctorCount = adminState.users
                  .where((u) => u['type'] == 'doctor')
                  .length;
              patientCount = adminState.users
                  .where((u) => u['type'] == 'patient')
                  .length;
            }

            final allRequests = signupState is SignupRequestsLoaded
                ? signupState.requests.whereType<SignupRequest>().toList()
                : <SignupRequest>[];

            final pending =
                allRequests.where((r) => r.status == 'pending').toList();
            final approved =
                allRequests.where((r) => r.status == 'approved').toList();
            final rejected =
                allRequests.where((r) => r.status == 'rejected').toList();

            final backlog = pending
                .where((r) =>
                    DateTime.now().difference(r.requestedAt).inDays > 7)
                .toList()
              ..sort((a, b) => a.requestedAt.compareTo(b.requestedAt));

            final approvalRate = allRequests.isEmpty
                ? 0.0
                : approved.length / allRequests.length;

            return _HomeContent(
              totalUsers: totalUsers,
              doctorCount: doctorCount,
              patientCount: patientCount,
              pending: pending,
              approved: approved,
              rejected: rejected,
              backlog: backlog,
              approvalRate: approvalRate,
              allRequests: allRequests,
            );
          },
        );
      },
    );
  }
}

// ─── Content ──────────────────────────────────────────────────────────────────

class _HomeContent extends StatelessWidget {
  final int totalUsers;
  final int doctorCount;
  final int patientCount;
  final List<SignupRequest> pending;
  final List<SignupRequest> approved;
  final List<SignupRequest> rejected;
  final List<SignupRequest> backlog;
  final double approvalRate;
  final List<SignupRequest> allRequests;

  const _HomeContent({
    required this.totalUsers,
    required this.doctorCount,
    required this.patientCount,
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.backlog,
    required this.approvalRate,
    required this.allRequests,
  });

  List<({String label, int count})> get _monthlyTrend {
    const months = [
      'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu',
      'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic',
    ];
    final now = DateTime.now();
    final result = <({String label, int count})>[];
    for (int i = 5; i >= 0; i--) {
      int m = now.month - i;
      int y = now.year;
      while (m <= 0) {
        m += 12;
        y--;
      }
      final count = allRequests
          .where((r) => r.requestedAt.year == y && r.requestedAt.month == m)
          .length;
      result.add((label: months[m - 1], count: count));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const weekdays = [
      'Lunedì', 'Martedì', 'Mercoledì', 'Giovedì',
      'Venerdì', 'Sabato', 'Domenica',
    ];
    const monthNames = [
      'gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno',
      'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre',
    ];
    final dateStr =
        '${weekdays[now.weekday - 1]}, ${now.day} ${monthNames[now.month - 1]} ${now.year}';

    final trend = _monthlyTrend;
    final maxTrend = trend.isEmpty
        ? 1
        : trend.map((t) => t.count).reduce((a, b) => a > b ? a : b).clamp(1, 999999);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Panoramica Piattaforma',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: CustomColors.verdeAbisso,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: CustomColors.verdeAbisso.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_done,
                        color: Color(0xFF4CAF50), size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Firebase connesso',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        color: CustomColors.verdeAbisso,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ── KPI row ────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _kpiCard(
                  'Utenti totali',
                  '$totalUsers',
                  Icons.people,
                  CustomColors.verdeAbisso,
                ),
              ),
              Expanded(
                child: _kpiCard(
                  'Professionisti',
                  '$doctorCount',
                  Icons.medical_services,
                  CustomColors.verdeMare,
                ),
              ),
              Expanded(
                child: _kpiCard(
                  'Pazienti',
                  '$patientCount',
                  Icons.personal_injury,
                  CustomColors.verdeTropicale,
                ),
              ),
              Expanded(
                child: _kpiCard(
                  'In attesa',
                  '${pending.length}',
                  Icons.pending_actions,
                  pending.isNotEmpty
                      ? Colors.orange
                      : const Color(0xFF4CAF50),
                ),
              ),
              Expanded(
                child: _kpiCard(
                  'Tasso approvazione',
                  allRequests.isEmpty
                      ? 'N/D'
                      : '${(approvalRate * 100).round()}%',
                  Icons.percent,
                  CustomColors.verdeAbisso,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Action queue + monthly trend ────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.assignment_late_outlined,
                              color: backlog.isNotEmpty
                                  ? Colors.orange
                                  : const Color(0xFF4CAF50),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Richiede Attenzione',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: CustomColors.verdeAbisso,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (backlog.isEmpty && pending.isEmpty)
                          _allGoodRow()
                        else ...[
                          if (backlog.isNotEmpty)
                            _alertRow(
                              icon: Icons.hourglass_top,
                              color: CustomColors.rossoSimone,
                              title:
                                  '${backlog.length} richieste in backlog',
                              subtitle:
                                  'In attesa da oltre 7 giorni — processarle al più presto',
                            ),
                          if (pending.isNotEmpty)
                            _alertRow(
                              icon: Icons.inbox_outlined,
                              color: Colors.orange,
                              title: '${pending.length} richieste pending',
                              subtitle:
                                  'Da esaminare nella sezione Signup Requests',
                            ),
                        ],
                        if (allRequests.isEmpty)
                          _alertRow(
                            icon: Icons.info_outline,
                            color: Colors.blue,
                            title: 'Nessuna richiesta ancora ricevuta',
                            subtitle:
                                'Il pannello si aggiornerà automaticamente',
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                flex: 5,
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.trending_up,
                                color: CustomColors.verdeMare, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Iscrizioni — ultimi 6 mesi',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: CustomColors.verdeAbisso,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (trend.every((t) => t.count == 0))
                          Text(
                            'Nessuna iscrizione nel periodo',
                            style: TextStyle(
                                fontFamily: 'Montserrat',
                                color: Colors.grey[500],
                                fontSize: 13),
                          )
                        else
                          ...trend.map((t) {
                            final pct = t.count / maxTrend;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(t.label,
                                          style: const TextStyle(
                                              fontFamily: 'Montserrat',
                                              fontSize: 13,
                                              fontWeight:
                                                  FontWeight.w500)),
                                      Text('${t.count}',
                                          style: TextStyle(
                                              fontFamily: 'Montserrat',
                                              fontSize: 12,
                                              color: Colors.grey[600])),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: pct,
                                      minHeight: 8,
                                      backgroundColor:
                                          Colors.grey.shade200,
                                      valueColor:
                                          const AlwaysStoppedAnimation<
                                                  Color>(
                                              CustomColors.verdeAbisso),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Snapshot richieste ──────────────────────────────────────────
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.analytics_outlined,
                          color: CustomColors.verdeAbisso, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Snapshot Richieste',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: CustomColors.verdeAbisso,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _snapshotBar(
                          'Approvate',
                          approved.length,
                          allRequests.length,
                          const Color(0xFF4CAF50),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _snapshotBar(
                          'Pending',
                          pending.length,
                          allRequests.length,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _snapshotBar(
                          'Rifiutate',
                          rejected.length,
                          allRequests.length,
                          CustomColors.rossoSimone,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Audit Log ──────────────────────────────────────────────────
          BlocBuilder<AuditLogBloc, AuditLogState>(
            builder: (context, auditState) {
              if (auditState is AuditLogLoaded && auditState.actions.isNotEmpty) {
                return _auditLogSection(auditState.actions);
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                Icon(icon, color: color, size: 28),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _alertRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _allGoodRow() {
    return Row(
      children: [
        const Icon(Icons.check_circle_outline,
            color: Color(0xFF4CAF50), size: 20),
        const SizedBox(width: 10),
        Text(
          'Tutto in ordine — nessuna azione richiesta',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _snapshotBar(
      String label, int count, int total, Color color) {
    final pct = total == 0 ? 0.0 : count / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            Text(
              '$count  (${(pct * 100).round()}%)',
              style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                  color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 10,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _auditLogSection(List<AdminAction> actions) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.history, color: CustomColors.verdeAbisso, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Attività recente',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: CustomColors.verdeAbisso,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Ultime ${actions.length} azioni',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...actions.take(20).map(_auditLogEntry),
          ],
        ),
      ),
    );
  }

  Widget _auditLogEntry(AdminAction action) {
    final isApprove = action.action == 'approve' || action.action == 'batch_approve';
    final color = isApprove ? const Color(0xFF4CAF50) : CustomColors.rossoSimone;
    final icon = isApprove ? Icons.check_circle : Icons.cancel;

    String actionLabel;
    if (action.action == 'approve') {
      actionLabel = 'Approvato';
    } else if (action.action == 'reject') {
      actionLabel = 'Rifiutato';
    } else if (action.action == 'batch_approve') {
      actionLabel = 'Batch approvazione (${action.batchCount ?? '?'})';
    } else if (action.action == 'batch_reject') {
      actionLabel = 'Batch rifiuto (${action.batchCount ?? '?'})';
    } else {
      actionLabel = action.action;
    }

    final diff = DateTime.now().difference(action.timestamp);
    final timeAgo = diff.inMinutes < 60
        ? '${diff.inMinutes}m fa'
        : diff.inHours < 24
            ? '${diff.inHours}h fa'
            : '${diff.inDays}g fa';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        '${action.adminName.isNotEmpty ? action.adminName : action.adminEmail} · $actionLabel',
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                if (action.requestName != null && action.requestName!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      action.requestName!,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                if (action.notes != null && action.notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      action.notes!,
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
