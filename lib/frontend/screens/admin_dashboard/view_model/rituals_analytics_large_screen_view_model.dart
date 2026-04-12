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
              const SizedBox(height: 32),

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
                    child: _topRitualsSection(),
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
    const categoryColors = {
      Ritual.categoryAlimentare: Colors.green,
      Ritual.categoryMotoria: Colors.orange,
      Ritual.categoryMentale: Colors.purple,
      Ritual.categoryBenessere: CustomColors.verdeAbisso,
    };

    final entries = Ritual.categoryLabels.entries.toList();

    return _sectionCard(
      title: 'Distribuzione per categoria',
      icon: Icons.category_outlined,
      child: Column(
        children: entries.map((entry) {
          final count = byCategory[entry.key] ?? 0;
          final pct = total == 0 ? 0.0 : count / total;
          final color = categoryColors[entry.key] ?? CustomColors.verdeAbisso;
          return _barRow(
            label: entry.value,
            count: count,
            pct: pct,
            color: color,
          );
        }).toList(),
      ),
    );
  }

  // ─── Top rituali section ─────────────────────────────────────────────────────

  Widget _topRitualsSection() {
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
                              color:
                                  i < 3 ? Colors.white : CustomColors.verdeAbisso,
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
                    ],
                  ),
                );
              }).toList(),
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
    const levelColors = {
      Ritual.levelPrincipiante: Colors.green,
      Ritual.levelIntermedio: Colors.orange,
      Ritual.levelAvanzato: Colors.red,
    };

    final entries = Ritual.levelLabels.entries.toList();

    return _sectionCard(
      title: 'Per livello',
      icon: Icons.bar_chart,
      child: Column(
        children: entries.map((entry) {
          final count = byLevel[entry.key] ?? 0;
          final pct = total == 0 ? 0.0 : count / total;
          final color = levelColors[entry.key] ?? Colors.grey;
          return _barRow(
            label: entry.value,
            count: count,
            pct: pct,
            color: color,
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
