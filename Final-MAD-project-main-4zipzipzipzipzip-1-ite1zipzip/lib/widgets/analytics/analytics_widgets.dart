import 'package:flutter/material.dart';

// ── Section label ──────────────────────────────────────────────────────────

class AnalyticsSectionLabel extends StatelessWidget {
  final String text;
  const AnalyticsSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF1F1A17),
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    );
  }
}

// ── KPI card ───────────────────────────────────────────────────────────────

class AnalyticsKpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final Color? accent;

  const AnalyticsKpiCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? const Color(0xFFC46A3D);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9E1D6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: const Color(0xFFA09489)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFA09489),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(
              sub!,
              style: const TextStyle(color: Color(0xFFA09489), fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Chart card container ───────────────────────────────────────────────────

class AnalyticsChartCard extends StatelessWidget {
  final Widget child;
  final double? height;
  final EdgeInsets? padding;

  const AnalyticsChartCard({
    super.key,
    required this.child,
    this.height,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9E1D6)),
      ),
      child: child,
    );
  }
}

// ── Funnel row ─────────────────────────────────────────────────────────────

class AnalyticsFunnelRow extends StatelessWidget {
  final String label;
  final int count;
  final double fraction;
  final Color color;
  final String? showRate;

  const AnalyticsFunnelRow({
    super.key,
    required this.label,
    required this.count,
    required this.fraction,
    required this.color,
    this.showRate,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: const TextStyle(
                color: Color(0xFF6E6258), fontSize: 12),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              backgroundColor: const Color(0xFFF5EDE5),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 9,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$count',
                style: const TextStyle(
                  color: Color(0xFF1F1A17),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (showRate != null)
                Text(
                  showRate!,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Insight tile ───────────────────────────────────────────────────────────

class AnalyticsInsightTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color color;

  const AnalyticsInsightTile({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.color = const Color(0xFFC46A3D),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                      color: Color(0xFF6E6258), fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ranking row ────────────────────────────────────────────────────────────

class AnalyticsRankingRow extends StatelessWidget {
  final int rank;
  final String title;
  final String subtitle;
  final String primaryValue;
  final String? secondaryValue;

  const AnalyticsRankingRow({
    super.key,
    required this.rank,
    required this.title,
    required this.subtitle,
    required this.primaryValue,
    this.secondaryValue,
  });

  @override
  Widget build(BuildContext context) {
    final isTop = rank <= 3;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9E1D6)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isTop
                  ? const Color(0xFFC46A3D)
                  : const Color(0xFFF5EDE5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '#$rank',
              style: TextStyle(
                color: isTop ? Colors.white : const Color(0xFFA09489),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF1F1A17),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                      color: Color(0xFFA09489), fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                primaryValue,
                style: const TextStyle(
                  color: Color(0xFF1F1A17),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              if (secondaryValue != null)
                Text(
                  secondaryValue!,
                  style: const TextStyle(
                      color: Color(0xFFA09489), fontSize: 11),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class AnalyticsEmptyState extends StatelessWidget {
  final String message;
  const AnalyticsEmptyState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFFA09489), fontSize: 13),
      ),
    );
  }
}
