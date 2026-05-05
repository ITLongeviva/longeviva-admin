import 'dart:convert' show utf8;
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../backend/bloc/patients_bloc.dart';
import '../../../../backend/models/patient_model.dart';
import '../../../../shared/utils/colors.dart';

class PatientsLargeScreenViewModel extends StatelessWidget {
  const PatientsLargeScreenViewModel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PatientsBloc, PatientsState>(
      builder: (context, state) {
        if (state is PatientsInitial || state is PatientsLoading) {
          return const Center(
            child: CircularProgressIndicator(color: CustomColors.verdeAbisso),
          );
        }
        if (state is PatientsError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    color: CustomColors.rossoSimone, size: 48),
                const SizedBox(height: 16),
                Text(state.message,
                    style: const TextStyle(fontFamily: 'Montserrat')),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () =>
                      context.read<PatientsBloc>().add(LoadPatients()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Riprova'),
                ),
              ],
            ),
          );
        }
        if (state is PatientsLoaded) {
          return _PatientsContent(patients: state.patients);
        }
        return const SizedBox.shrink();
      },
    );
  }
}

// ─── Content ──────────────────────────────────────────────────────────────────

class _PatientsContent extends StatefulWidget {
  final List<Patient> patients;

  const _PatientsContent({required this.patients});

  @override
  State<_PatientsContent> createState() => _PatientsContentState();
}

class _PatientsContentState extends State<_PatientsContent> {
  String? _sexFilter;
  String? _ageFilter;
  bool? _onboardingFilter;
  String _nameSearch = '';
  late TextEditingController _searchController;
  String _sortBy = 'name';
  bool _sortAsc = true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  int _ageOf(Patient p) {
    if (p.birthdate == null) return -1;
    final now = DateTime.now();
    int age = now.year - p.birthdate!.year;
    if (now.month < p.birthdate!.month ||
        (now.month == p.birthdate!.month && now.day < p.birthdate!.day)) {
      age--;
    }
    return age;
  }

  String _sexNorm(Patient p) {
    final s = p.sex.trim().toUpperCase();
    if (s == 'M') return 'M';
    if (s == 'F') return 'F';
    return 'N.D.';
  }

  bool _matchesAge(Patient p) {
    if (_ageFilter == null) return true;
    final age = _ageOf(p);
    if (age < 0) return false;
    switch (_ageFilter) {
      case '<18':
        return age < 18;
      case '18–30':
        return age >= 18 && age <= 30;
      case '31–50':
        return age >= 31 && age <= 50;
      case '>50':
        return age > 50;
      default:
        return true;
    }
  }

  List<Patient> get _filtered {
    var list = widget.patients.where((p) {
      if (_sexFilter != null && _sexNorm(p) != _sexFilter) return false;
      if (!_matchesAge(p)) return false;
      if (_onboardingFilter != null &&
          p.hasCompletedOnboarding != _onboardingFilter) return false;
      if (_nameSearch.isNotEmpty) {
        final q = _nameSearch.toLowerCase();
        final full = '${p.name} ${p.surname}'.toLowerCase();
        final email = p.email.toLowerCase();
        if (!full.contains(q) && !email.contains(q)) return false;
      }
      return true;
    }).toList();

    list.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case 'age':
          final ageA = _ageOf(a);
          final ageB = _ageOf(b);
          cmp = ageA.compareTo(ageB);
          break;
        case 'date':
          final dateA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          cmp = dateA.compareTo(dateB);
          break;
        default:
          cmp = '${a.surname} ${a.name}'
              .toLowerCase()
              .compareTo('${b.surname} ${b.name}'.toLowerCase());
      }
      return _sortAsc ? cmp : -cmp;
    });

    return list;
  }

  void _resetFilters() {
    setState(() {
      _sexFilter = null;
      _ageFilter = null;
      _onboardingFilter = null;
      _nameSearch = '';
      _searchController.clear();
      _sortBy = 'name';
      _sortAsc = true;
    });
  }

  bool get _hasActiveFilters =>
      _sexFilter != null ||
      _ageFilter != null ||
      _onboardingFilter != null ||
      _nameSearch.isNotEmpty;

  void _exportCsv(List<Patient> patients) {
    String esc(String s) => '"${s.replaceAll('"', '""')}"';

    final buffer = StringBuffer();
    buffer.writeln(
        'Cognome,Nome,Email,Sesso,Età,Città,"Dottore assegnato","Onboarding completato","Iscritto il"');

    for (final p in patients) {
      final age = _ageOf(p);
      final ageStr = age >= 0 ? '$age' : 'N.D.';
      final doctorStr = p.assignedDoctorId != null ? 'Sì' : 'No';
      final onboardingStr = p.hasCompletedOnboarding ? 'Sì' : 'No';
      final dateStr = p.createdAt != null
          ? DateFormat('dd/MM/yyyy').format(p.createdAt!)
          : '';

      buffer.writeln([
        esc(p.surname),
        esc(p.name),
        esc(p.email),
        esc(_sexNorm(p)),
        esc(ageStr),
        esc(p.cityOfResidence),
        esc(doctorStr),
        esc(onboardingStr),
        esc(dateStr),
      ].join(','));
    }

    final bytes = utf8.encode(buffer.toString());
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download',
          'pazienti_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _filterSection(),
          const SizedBox(height: 20),
          _kpiRow(filtered),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _bySexChart(filtered)),
              const SizedBox(width: 16),
              Expanded(child: _byAgeChart(filtered)),
              const SizedBox(width: 16),
              Expanded(child: _byMonthChart(widget.patients)),
            ],
          ),
          const SizedBox(height: 20),
          _patientTable(filtered),
        ],
      ),
    );
  }

  // ── Filter section ───────────────────────────────────────────────────────────

  Widget _filterSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cerca per nome, cognome o email…',
                    hintStyle: const TextStyle(
                        fontFamily: 'Montserrat', fontSize: 13),
                    prefixIcon:
                        const Icon(Icons.search, color: CustomColors.verdeAbisso),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: CustomColors.verdeMare),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: CustomColors.verdeAbisso),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _nameSearch = v),
                ),
              ),
              if (_hasActiveFilters) ...[
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.clear,
                      size: 16, color: CustomColors.rossoSimone),
                  label: const Text(
                    'Resetta filtri',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 13,
                      color: CustomColors.rossoSimone,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.refresh,
                    size: 18, color: CustomColors.verdeMare),
                tooltip: 'Ricarica dati',
                onPressed: () =>
                    context.read<PatientsBloc>().add(LoadPatients()),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _filterRow(
            'Sesso',
            ['M', 'F', 'N.D.'].map((v) => _singleChip(v, _sexFilter, (sel) {
              setState(() => _sexFilter = sel);
            })).toList(),
          ),
          const SizedBox(height: 8),
          _filterRow(
            'Età',
            ['<18', '18–30', '31–50', '>50']
                .map((v) => _singleChip(v, _ageFilter, (sel) {
                      setState(() => _ageFilter = sel);
                    }))
                .toList(),
          ),
          const SizedBox(height: 8),
          _filterRow(
            'Onboarding',
            [
              _boolChip('Completato', true, _onboardingFilter,
                  (v) => setState(() => _onboardingFilter = v)),
              _boolChip('Incompleto', false, _onboardingFilter,
                  (v) => setState(() => _onboardingFilter = v)),
            ],
          ),
        ],
      ),
    );
  }

  // ── KPI row ──────────────────────────────────────────────────────────────────

  Widget _kpiRow(List<Patient> filtered) {
    final total = filtered.length;

    final ages = filtered
        .map(_ageOf)
        .where((a) => a >= 0)
        .toList();
    final avgAge = ages.isEmpty
        ? null
        : ages.fold(0, (s, a) => s + a) / ages.length;

    final withDoctorCount =
        filtered.where((p) => p.assignedDoctorId != null).length;

    final onboardingCount =
        filtered.where((p) => p.hasCompletedOnboarding).length;
    final pctOnboarding =
        total == 0 ? 0.0 : onboardingCount / total * 100;

    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final lastMonth = filtered
        .where((p) => p.createdAt != null && p.createdAt!.isAfter(cutoff))
        .length;

    return Row(
      children: [
        Expanded(
            child: _kpi('$total', 'Pazienti totali', Icons.people_outline,
                CustomColors.verdeAbisso)),
        Expanded(
            child: _kpi(
                avgAge == null ? 'N/D' : avgAge.toStringAsFixed(1),
                'Età media',
                Icons.cake_outlined,
                CustomColors.verdeMare)),
        Expanded(
            child: _kpi(
                total == 0 ? '—' : '$withDoctorCount',
                'Con dottore assegnato',
                Icons.medical_services_outlined,
                const Color(0xFF4CAF50))),
        Expanded(
            child: _kpi('${pctOnboarding.round()}%', 'Onboarding completato',
                Icons.task_alt, Colors.orange)),
        Expanded(
            child: _kpi('$lastMonth', 'Iscritti ultimo mese',
                Icons.calendar_today_outlined, Colors.purple)),
      ],
    );
  }

  // ── Charts ───────────────────────────────────────────────────────────────────

  Widget _bySexChart(List<Patient> filtered) {
    final total = filtered.length;
    final counts = <String, int>{'M': 0, 'F': 0, 'N.D.': 0};
    for (final p in filtered) {
      counts[_sexNorm(p)] = (counts[_sexNorm(p)] ?? 0) + 1;
    }
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _chartTitle('Distribuzione per sesso'),
          const SizedBox(height: 16),
          _barRow('M', counts['M']!, total, const Color(0xFF42A5F5)),
          _barRow('F', counts['F']!, total, const Color(0xFFEC407A)),
          _barRow('N.D.', counts['N.D.']!, total, Colors.grey),
        ],
      ),
    );
  }

  Widget _byAgeChart(List<Patient> filtered) {
    final bands = ['<18', '18–30', '31–50', '>50'];
    final colors = [
      Colors.teal,
      CustomColors.verdeMare,
      CustomColors.verdeAbisso,
      Colors.indigo,
    ];
    final counts = <String, int>{};
    for (final b in bands) {
      counts[b] = 0;
    }
    for (final p in filtered) {
      final age = _ageOf(p);
      if (age < 0) continue;
      if (age < 18) {
        counts['<18'] = counts['<18']! + 1;
      } else if (age <= 30) {
        counts['18–30'] = counts['18–30']! + 1;
      } else if (age <= 50) {
        counts['31–50'] = counts['31–50']! + 1;
      } else {
        counts['>50'] = counts['>50']! + 1;
      }
    }
    final knownTotal =
        counts.values.fold(0, (s, v) => s + v);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _chartTitle('Distribuzione per età'),
          const SizedBox(height: 16),
          ...bands.asMap().entries.map((e) => _barRow(
                e.value,
                counts[e.value]!,
                knownTotal == 0 ? 1 : knownTotal,
                colors[e.key],
              )),
        ],
      ),
    );
  }

  Widget _byMonthChart(List<Patient> allPatients) {
    final now = DateTime.now();
    final months = List.generate(6, (i) {
      final d = DateTime(now.year, now.month - (5 - i), 1);
      return d;
    });

    final counts = <String, int>{};
    for (final m in months) {
      final key = '${m.year}-${m.month.toString().padLeft(2, '0')}';
      counts[key] = 0;
    }

    for (final p in allPatients) {
      if (p.createdAt == null) continue;
      final key =
          '${p.createdAt!.year}-${p.createdAt!.month.toString().padLeft(2, '0')}';
      if (counts.containsKey(key)) {
        counts[key] = counts[key]! + 1;
      }
    }

    final maxCount = counts.values.fold(0, (a, b) => a > b ? a : b);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _chartTitle('Iscrizioni (ultimi 6 mesi)'),
          const SizedBox(height: 16),
          ...months.map((m) {
            final key =
                '${m.year}-${m.month.toString().padLeft(2, '0')}';
            final count = counts[key] ?? 0;
            final label = DateFormat('MMM yy', 'it').format(m);
            return _barRow(
              label,
              count,
              maxCount == 0 ? 1 : maxCount,
              CustomColors.verdeTropicale,
            );
          }),
        ],
      ),
    );
  }

  // ── Table ────────────────────────────────────────────────────────────────────

  Widget _patientTable(List<Patient> filtered) {
    final rows = filtered.take(100).toList();

    void toggleSort(String key) {
      setState(() {
        if (_sortBy == key) {
          _sortAsc = !_sortAsc;
        } else {
          _sortBy = key;
          _sortAsc = true;
        }
      });
    }

    Widget sortHeader(String label, String key, int flex) {
      final active = _sortBy == key;
      return Expanded(
        flex: flex,
        child: GestureDetector(
          onTap: () => toggleSort(key),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: active
                      ? CustomColors.verdeAbisso
                      : Colors.grey[700],
                ),
              ),
              if (active) ...[
                const SizedBox(width: 4),
                Icon(
                  _sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                  color: CustomColors.verdeAbisso,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _chartTitle('Pazienti (${filtered.length})'),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: () => _exportCsv(filtered),
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Esporta CSV'),
                style: TextButton.styleFrom(
                    foregroundColor: CustomColors.verdeAbisso),
              ),
              const Spacer(),
              if (filtered.length > 100)
                Text(
                  'Visualizzati: 100 di ${filtered.length}',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: CustomColors.mentaFredda.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                sortHeader('Nome', 'name', 3),
                sortHeader('Sesso', 'sex', 1),
                sortHeader('Età', 'age', 1),
                const Expanded(
                  flex: 2,
                  child: Text(
                    'Città',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const Expanded(
                  flex: 1,
                  child: Text(
                    'Dottore',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const Expanded(
                  flex: 1,
                  child: Text(
                    'Onboarding',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                sortHeader('Iscritto il', 'date', 2),
              ],
            ),
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'Nessun paziente trovato',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            )
          else
            ...rows.asMap().entries.map((e) {
              final i = e.key;
              final p = e.value;
              final age = _ageOf(p);
              final ageLabel = age >= 0 ? '$age' : '—';
              final dateLabel = p.createdAt != null
                  ? DateFormat('dd/MM/yyyy').format(p.createdAt!)
                  : '—';
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: i.isEven ? Colors.white : Colors.grey.shade50,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade100),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        '${p.surname} ${p.name}'.trim(),
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        _sexNorm(p),
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        ageLabel,
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        p.cityOfResidence.isEmpty ? '—' : p.cityOfResidence,
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Icon(
                        p.assignedDoctorId != null
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: p.assignedDoctorId != null
                            ? const Color(0xFF4CAF50)
                            : Colors.grey.shade400,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Icon(
                        p.hasCompletedOnboarding
                            ? Icons.task_alt
                            : Icons.pending_outlined,
                        size: 18,
                        color: p.hasCompletedOnboarding
                            ? const Color(0xFF4CAF50)
                            : Colors.orange,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        dateLabel,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── Shared helpers ───────────────────────────────────────────────────────────

  Widget _kpi(String value, String label, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                Icon(icon, color: color, size: 24),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: child,
      ),
    );
  }

  Widget _chartTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: CustomColors.verdeAbisso,
      ),
    );
  }

  Widget _barRow(String label, int count, int total, Color color) {
    final pct = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 12,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text(
              '$count',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterRow(String label, List<Widget> chips) {
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: chips,
            ),
          ),
        ],
      ),
    );
  }

  Widget _singleChip(
    String label,
    String? current,
    void Function(String?) onChange,
  ) {
    final selected = current == label;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 12,
          color: selected ? Colors.white : Colors.black87,
        ),
      ),
      selected: selected,
      onSelected: (_) => onChange(selected ? null : label),
      selectedColor: CustomColors.verdeAbisso,
      checkmarkColor: Colors.white,
      backgroundColor: Colors.grey.shade100,
      side: BorderSide(
        color: selected ? CustomColors.verdeAbisso : Colors.grey.shade300,
      ),
    );
  }

  Widget _boolChip(
    String label,
    bool value,
    bool? current,
    void Function(bool?) onChange,
  ) {
    final selected = current == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 12,
          color: selected ? Colors.white : Colors.black87,
        ),
      ),
      selected: selected,
      onSelected: (_) => onChange(selected ? null : value),
      selectedColor: CustomColors.verdeAbisso,
      checkmarkColor: Colors.white,
      backgroundColor: Colors.grey.shade100,
      side: BorderSide(
        color: selected ? CustomColors.verdeAbisso : Colors.grey.shade300,
      ),
    );
  }
}
