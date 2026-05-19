import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../backend/bloc/ritual_bloc.dart';
import '../../../../backend/models/ritual_model.dart';
import '../../../../shared/utils/colors.dart';

class RitualsAnalyticsLargeScreenViewModel extends StatelessWidget {
  const RitualsAnalyticsLargeScreenViewModel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RitualBloc, RitualState>(
      builder: (context, state) {
        if (state is RitualLoading || state is RitualInitial) {
          return const Center(
            child: CircularProgressIndicator(color: CustomColors.verdeAbisso),
          );
        }

        if (state is RitualError) {
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
                      context.read<RitualBloc>().add(LoadRitualAnalytics()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Riprova'),
                ),
              ],
            ),
          );
        }

        if (state is RitualLoaded) {
          return _RitualsAnalyticsContent(rituals: state.rituals);
        }

        return const SizedBox.shrink();
      },
    );
  }
}

// ─── Content ──────────────────────────────────────────────────────────────────

class _RitualsAnalyticsContent extends StatelessWidget {
  final List<Ritual> rituals;

  const _RitualsAnalyticsContent({required this.rituals});

  // ── Computed stats ──────────────────────────────────────────────────────────

  int get total => rituals.length;
  int get active => rituals.where((r) => r.isActive).length;
  int get featured => rituals.where((r) => r.isFeatured).length;
  int get totalUsage => rituals.fold(0, (sum, r) => sum + r.usageCount);

  double get avgPrice {
    final paid = rituals.where((r) => r.price > 0).toList();
    if (paid.isEmpty) return 0;
    return paid.fold(0.0, (sum, r) => sum + r.price) / paid.length;
  }

  Map<String, int> get byCategory {
    final map = <String, int>{};
    for (final r in rituals) {
      map[r.category] = (map[r.category] ?? 0) + 1;
    }
    return map;
  }

  Map<String, int> get byLevel {
    final map = <String, int>{};
    for (final r in rituals) {
      map[r.level] = (map[r.level] ?? 0) + 1;
    }
    return map;
  }

  Map<String, int> get byAuthorRole {
    final map = <String, int>{};
    for (final r in rituals) {
      final role = r.authorRole ?? 'admin';
      map[role] = (map[role] ?? 0) + 1;
    }
    return map;
  }

  Map<String, int> get byPriceRange {
    final map = {
      'Gratuito': 0,
      '€1 – €20': 0,
      '€21 – €50': 0,
      '€51 – €100': 0,
      'Oltre €100': 0,
    };
    for (final r in rituals) {
      if (r.price == 0) {
        map['Gratuito'] = map['Gratuito']! + 1;
      } else if (r.price <= 20) {
        map['€1 – €20'] = map['€1 – €20']! + 1;
      } else if (r.price <= 50) {
        map['€21 – €50'] = map['€21 – €50']! + 1;
      } else if (r.price <= 100) {
        map['€51 – €100'] = map['€51 – €100']! + 1;
      } else {
        map['Oltre €100'] = map['Oltre €100']! + 1;
      }
    }
    return map;
  }

  List<Ritual> get topByUsage {
    final sorted = [...rituals]
      ..sort((a, b) => b.usageCount.compareTo(a.usageCount));
    return sorted.take(5).toList();
  }

  double get catalogRevenueGenerated =>
      rituals.fold(0.0, (sum, r) => sum + r.usageCount * r.price);

  int get freeRitualsCount => rituals.where((r) => r.price == 0).length;
  int get paidRitualsCount => rituals.where((r) => r.price > 0).length;

  Map<String, double> get avgUsageByCategory {
    final result = <String, double>{};
    for (final cat in [
      Ritual.categoryAlimentare,
      Ritual.categoryMotoria,
      Ritual.categoryMentale,
      Ritual.categoryBenessere,
    ]) {
      final items = rituals.where((r) => r.category == cat).toList();
      result[cat] = items.isEmpty
          ? 0
          : items.fold(0, (s, r) => s + r.usageCount) / items.length;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analytics Rituali',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: CustomColors.verdeAbisso,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Panoramica dei rituali disponibili sulla piattaforma',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Aggiorna',
                  onPressed: () =>
                      context.read<RitualBloc>().add(LoadRitualAnalytics()),
                  icon: const Icon(Icons.refresh,
                      color: CustomColors.verdeAbisso),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ── KPI cards ─────────────────────────────────────────────────────
            if (total == 0)
              _emptyState()
            else ...[
              _kpiRow(),
              const SizedBox(height: 24),

              // ── Valore del catalogo ──────────────────────────────────────
              _catalogValueSection(),
              const SizedBox(height: 24),

              // ── Row: category + top rituali ──────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: _categorySection(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 5,
                    child: _topRitualsSection(context),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Row: prezzi + livelli + autori ───────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: _priceSection(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: _levelSection(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: _authorRoleSection(),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── KPI row ────────────────────────────────────────────────────────────────

  Widget _kpiRow() {
    return Row(
      children: [
        Expanded(
          child: _kpiCard(
            label: 'Rituali totali',
            value: '$total',
            icon: Icons.auto_awesome,
            color: CustomColors.verdeAbisso,
          ),
        ),
        Expanded(
          child: _kpiCard(
            label: 'Rituali attivi',
            value: '$active',
            icon: Icons.check_circle_outline,
            color: CustomColors.verdeMare,
          ),
        ),
        Expanded(
          child: _kpiCard(
            label: 'Utilizzi totali',
            value: '$totalUsage',
            icon: Icons.people_outline,
            color: CustomColors.verdeTropicale,
          ),
        ),
        Expanded(
          child: _kpiCard(
            label: 'Prezzo medio',
            value: avgPrice == 0
                ? 'N/D'
                : '€${avgPrice.toStringAsFixed(0)}',
            icon: Icons.euro_outlined,
            color: Colors.amber.shade700,
          ),
        ),
        Expanded(
          child: _kpiCard(
            label: 'In evidenza',
            value: '$featured',
            icon: Icons.star_outline,
            color: Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _kpiCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
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

  // ─── Category section ────────────────────────────────────────────────────────

  Widget _categorySection() {
    final categoryEntries = [
      (key: Ritual.categoryAlimentare, label: 'Salute Alimentare',  color: const Color(0xFF4CAF50)),
      (key: Ritual.categoryMotoria,    label: 'Salute Motoria',     color: const Color(0xFFFF9800)),
      (key: Ritual.categoryMentale,    label: 'Salute Mentale',     color: const Color(0xFF9C27B0)),
      (key: Ritual.categoryBenessere,  label: 'Benessere Generale', color: const Color(0xFF025861)),
    ];

    return _sectionCard(
      title: 'Distribuzione per categoria',
      icon: Icons.category_outlined,
      child: Column(
        children: categoryEntries.map((entry) {
          final count = byCategory[entry.key] ?? 0;
          final pct = total == 0 ? 0.0 : count / total;
          return _barRow(
            label: entry.label,
            count: count,
            pct: pct,
            color: entry.color,
          );
        }).toList(),
      ),
    );
  }

  // ─── Top rituali section ─────────────────────────────────────────────────────

  Widget _topRitualsSection(BuildContext context) {
    return _sectionCard(
      title: 'Top 5 rituali più usati',
      icon: Icons.trending_up,
      child: topByUsage.isEmpty
          ? _noDataText()
          : Column(
              children: topByUsage.asMap().entries.map((entry) {
                final i = entry.key;
                final r = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _showRitualDetail(context, r, rank: i + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: i == 0
                                  ? Colors.amber
                                  : i == 1
                                      ? Colors.grey.shade400
                                      : i == 2
                                          ? const Color(0xFFCD7F32)
                                          : CustomColors.perla,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: i < 3 ? Colors.white : CustomColors.verdeAbisso,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.title,
                                  style: const TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  r.categoryLabel,
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: CustomColors.verdeAbisso.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${r.usageCount} usi',
                              style: const TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: CustomColors.verdeAbisso,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: CustomColors.verdeAbisso,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  void _showRitualDetail(BuildContext context, Ritual ritual, {int? rank}) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 720),
          child: _RitualDetailPanel(
            ritual: ritual,
            rank: rank,
            totalRituals: total,
            totalUsage: totalUsage,
          ),
        ),
      ),
    );
  }

  // ─── Price section ───────────────────────────────────────────────────────────

  Widget _priceSection() {
    final priceColors = [
      Colors.green,
      Colors.teal,
      Colors.orange,
      Colors.deepOrange,
      Colors.red,
    ];

    final entries = byPriceRange.entries.toList();

    return _sectionCard(
      title: 'Fasce di prezzo',
      icon: Icons.euro_outlined,
      child: Column(
        children: entries.asMap().entries.map((e) {
          final i = e.key;
          final label = e.value.key;
          final count = e.value.value;
          final pct = total == 0 ? 0.0 : count / total;
          return _barRow(
            label: label,
            count: count,
            pct: pct,
            color: priceColors[i % priceColors.length],
          );
        }).toList(),
      ),
    );
  }

  // ─── Level section ───────────────────────────────────────────────────────────

  Widget _levelSection() {
    final levelEntries = [
      (key: Ritual.levelPrincipiante, label: 'Principiante', color: const Color(0xFF4CAF50)),
      (key: Ritual.levelIntermedio,   label: 'Intermedio',   color: const Color(0xFFFF9800)),
      (key: Ritual.levelAvanzato,     label: 'Avanzato',     color: const Color(0xFFF44336)),
    ];

    return _sectionCard(
      title: 'Per livello',
      icon: Icons.bar_chart,
      child: Column(
        children: levelEntries.map((entry) {
          final count = byLevel[entry.key] ?? 0;
          final pct = total == 0 ? 0.0 : count / total;
          return _barRow(
            label: entry.label,
            count: count,
            pct: pct,
            color: entry.color,
          );
        }).toList(),
      ),
    );
  }

  // ─── Author role section ─────────────────────────────────────────────────────

  Widget _authorRoleSection() {
    const roleLabels = {
      'NUTRITIONIST': 'Prof. salute alimentare',
      'PERSONAL TRAINER': 'Prof. salute motoria',
      'PSYCHOLOGIST': 'Prof. salute mentale',
      'admin': 'Team Longeviva',
    };

    const roleColors = {
      'NUTRITIONIST': Colors.green,
      'PERSONAL TRAINER': Colors.orange,
      'PSYCHOLOGIST': Colors.purple,
      'admin': CustomColors.verdeAbisso,
    };

    return _sectionCard(
      title: 'Per autore',
      icon: Icons.person_outline,
      child: byAuthorRole.isEmpty
          ? _noDataText()
          : Column(
              children: byAuthorRole.entries.map((entry) {
                final label = roleLabels[entry.key] ?? entry.key;
                final count = entry.value;
                final pct = total == 0 ? 0.0 : count / total;
                final color = roleColors[entry.key] ?? Colors.grey;
                return _barRow(
                  label: label,
                  count: count,
                  pct: pct,
                  color: color,
                );
              }).toList(),
            ),
    );
  }

  // ─── Valore del catalogo ─────────────────────────────────────────────────────

  Widget _catalogValueSection() {
    final revenue = catalogRevenueGenerated;
    final avgUsage = avgUsageByCategory;
    final avgTotal = total == 0 ? 0.0 : totalUsage / total;

    final categoryEntries = [
      (key: Ritual.categoryAlimentare, label: 'Salute Alimentare', color: const Color(0xFF4CAF50)),
      (key: Ritual.categoryMotoria,    label: 'Salute Motoria',    color: const Color(0xFFFF9800)),
      (key: Ritual.categoryMentale,    label: 'Salute Mentale',    color: const Color(0xFF9C27B0)),
      (key: Ritual.categoryBenessere,  label: 'Benessere Generale',color: const Color(0xFF025861)),
    ];

    final maxAvg = avgUsage.values.isEmpty
        ? 1.0
        : avgUsage.values.reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity);

    return _sectionCard(
      title: 'Valore del Catalogo',
      icon: Icons.insights,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _valueStat(
                  revenue == 0 ? '€0' : '€${revenue.toStringAsFixed(0)}',
                  'Ricavi generati',
                  Icons.savings_outlined,
                  const Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _valueStat(
                  '$paidRitualsCount / $total',
                  'Rituali a pagamento',
                  Icons.euro,
                  Colors.amber.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _valueStat(
                  avgTotal == 0 ? '0' : avgTotal.toStringAsFixed(1),
                  'Utilizzi medi per rituale',
                  Icons.people_outline,
                  CustomColors.verdeMare,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Efficacia per categoria (utilizzi medi)',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          ...categoryEntries.map((e) {
            final avg = avgUsage[e.key] ?? 0;
            return _avgBarRow(
              label: e.label,
              avg: avg,
              maxAvg: maxAvg,
              color: e.color,
            );
          }),
        ],
      ),
    );
  }

  Widget _valueStat(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avgBarRow({
    required String label,
    required double avg,
    required double maxAvg,
    required Color color,
  }) {
    final pct = maxAvg == 0 ? 0.0 : (avg / maxAvg).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${avg.toStringAsFixed(1)} usi medi',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Shared widgets ──────────────────────────────────────────────────────────

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: CustomColors.verdeAbisso, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: CustomColors.verdeAbisso,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  Widget _barRow({
    required String label,
    required int count,
    required double pct,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$count  (${(pct * 100).round()}%)',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _noDataText() {
    return Text(
      'Nessun dato disponibile',
      style: TextStyle(
        fontFamily: 'Montserrat',
        color: Colors.grey[500],
        fontSize: 14,
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(
          children: [
            Icon(Icons.auto_awesome,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'Nessun rituale trovato',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: CustomColors.verdeAbisso,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'I rituali creati dalla piattaforma appariranno qui.',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Ritual Detail Panel ──────────────────────────────────────────────────────

class _RitualDetailPanel extends StatelessWidget {
  final Ritual ritual;
  final int? rank;
  final int totalRituals;
  final int totalUsage;

  const _RitualDetailPanel({
    required this.ritual,
    this.rank,
    required this.totalRituals,
    required this.totalUsage,
  });

  Color get _categoryColor {
    switch (ritual.category) {
      case Ritual.categoryAlimentare: return const Color(0xFF4CAF50);
      case Ritual.categoryMotoria:    return const Color(0xFFFF9800);
      case Ritual.categoryMentale:    return const Color(0xFF9C27B0);
      default:                        return CustomColors.verdeAbisso;
    }
  }

  Color get _levelColor {
    switch (ritual.level) {
      case Ritual.levelPrincipiante: return const Color(0xFF4CAF50);
      case Ritual.levelIntermedio:   return const Color(0xFFFF9800);
      case Ritual.levelAvanzato:     return const Color(0xFFF44336);
      default:                       return Colors.grey;
    }
  }

  String get _authorRoleLabel {
    switch (ritual.authorRole) {
      case 'NUTRITIONIST':     return 'Prof. salute alimentare';
      case 'PERSONAL TRAINER': return 'Prof. salute motoria';
      case 'PSYCHOLOGIST':     return 'Prof. salute mentale';
      case 'admin':            return 'Team Longeviva';
      default:                 return ritual.authorRole ?? 'Sconosciuto';
    }
  }

  @override
  Widget build(BuildContext context) {
    final avgUsage = totalRituals > 0 ? totalUsage / totalRituals : 0.0;
    final usagePct = totalUsage > 0 ? (ritual.usageCount / totalUsage * 100) : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ─────────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: CustomColors.verdeAbisso,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      ritual.title,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _badge(ritual.categoryLabel, _categoryColor),
                  _badge(ritual.levelLabel, _levelColor),
                  if (ritual.isActive)
                    _badge('Attivo', Colors.green.shade600)
                  else
                    _badge('Inattivo', Colors.red.shade400),
                  if (ritual.isFeatured)
                    _badge('In evidenza', Colors.amber.shade700),
                  if (rank != null)
                    _badge('Top #$rank', Colors.white.withOpacity(0.25)),
                ],
              ),
            ],
          ),
        ),

        // ── Scrollable content ──────────────────────────────────────────────
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stat boxes
                Row(
                  children: [
                    Expanded(
                      child: _statBox(
                        Icons.people_outline,
                        '${ritual.usageCount}',
                        'Utilizzi',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statBox(
                        Icons.euro,
                        ritual.formattedPrice,
                        'Prezzo',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statBox(
                        Icons.calendar_today_outlined,
                        '${ritual.durationDays} gg',
                        'Durata',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Insight box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CustomColors.verdeAbisso.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: CustomColors.verdeAbisso.withOpacity(0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Insight utilizzo',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: CustomColors.verdeAbisso,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${usagePct.toStringAsFixed(1)}% del totale utilizzi sulla piattaforma',
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ritual.usageCount == 0
                            ? 'Non ancora utilizzato'
                            : ritual.usageCount > avgUsage
                                ? 'Sopra la media (media: ${avgUsage.toStringAsFixed(1)} usi)'
                                : 'Sotto la media (media: ${avgUsage.toStringAsFixed(1)} usi)',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 13,
                          color: ritual.usageCount > avgUsage
                              ? CustomColors.verdeMare
                              : Colors.orange.shade700,
                        ),
                      ),
                      if (rank != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Posizione #$rank tra i rituali più usati',
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: CustomColors.verdeAbisso,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                if (ritual.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Descrizione',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: CustomColors.verdeAbisso,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ritual.description,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],

                if (ritual.tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Tag',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: CustomColors.verdeAbisso,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ritual.tags
                        .map(
                          (tag) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: CustomColors.mentaFredda,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 12,
                                color: CustomColors.verdeAbisso,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],

                if (ritual.authorName != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Autore',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: CustomColors.verdeAbisso,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: CustomColors.verdeMare,
                        child: Icon(Icons.person, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ritual.authorName!,
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            _authorRoleLabel,
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),
                Divider(color: Colors.grey.shade200),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Creato: ${_formatDate(ritual.createdAt)}',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                    if (ritual.updatedAt != null)
                      Text(
                        'Aggiornato: ${_formatDate(ritual.updatedAt!)}',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _statBox(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: CustomColors.verdeAbisso),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: CustomColors.verdeAbisso,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
