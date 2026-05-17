import 'package:flutter/material.dart';

// ── Formatters ─────────────────────────────────────────────────────────────

class AnalyticsFormatters {
  AnalyticsFormatters._();

  static String currency(double amount) {
    if (amount >= 1000000) {
      return '\$${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '\$${(amount / 1000).toStringAsFixed(1)}k';
    }
    return '\$${amount.toStringAsFixed(0)}';
  }

  static String pct(double value, {int decimals = 0}) =>
      '${value.toStringAsFixed(decimals)}%';

  static String count(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  static String hourLabel(int h) {
    if (h == 0) return '12am';
    if (h == 12) return '12pm';
    if (h < 12) return '${h}am';
    return '${h - 12}pm';
  }

  static String monthAbbr(int month) {
    const names = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return names[month.clamp(1, 12)];
  }

  static String relativeDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return 'Just now';
  }
}

// ── Color helpers ──────────────────────────────────────────────────────────

class AnalyticsColors {
  AnalyticsColors._();

  static const primary = Color(0xFFC46A3D);
  static const muted = Color(0xFFA09489);
  static const success = Color(0xFF3D7A5A);
  static const warning = Color(0xFFB7791F);
  static const danger = Color(0xFFC24A3A);
  static const blue = Color(0xFF5A6F8C);
  static const purple = Color(0xFF6A1B9A);

  static Color rateColor(double rate, {double good = 70, double ok = 40}) {
    if (rate >= good) return success;
    if (rate >= ok) return blue;
    return danger;
  }

  static Color severityColor(String severity) {
    switch (severity) {
      case 'high':
        return danger;
      case 'medium':
        return warning;
      default:
        return blue;
    }
  }

  static Color utilColor(double pct) {
    if (pct >= 60) return success;
    if (pct >= 30) return warning;
    return danger;
  }

  static const chartPalette = [
    Color(0xFFC46A3D),
    Color(0xFF3D7A5A),
    Color(0xFF5A6F8C),
    Color(0xFFB7791F),
    Color(0xFFC24A3A),
    Color(0xFF7A5C8C),
    Color(0xFFA09489),
  ];
}

// ── Stat calculators ───────────────────────────────────────────────────────

class AnalyticsCalculators {
  AnalyticsCalculators._();

  static double safeRate(num numerator, num denominator) {
    if (denominator == 0) return 0.0;
    return (numerator / denominator * 100).clamp(0.0, 100.0);
  }

  static double safeFraction(num numerator, num denominator) {
    if (denominator == 0) return 0.0;
    return (numerator / denominator).clamp(0.0, 1.0);
  }

  static double average(Iterable<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static int consecutiveStreak(List<DateTime> sortedDates) {
    if (sortedDates.isEmpty) return 0;
    int streak = 1;
    for (var i = 1; i < sortedDates.length; i++) {
      final diff = sortedDates[i].difference(sortedDates[i - 1]).inDays;
      if (diff <= 30) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  static int bestConsecutiveStreak(List<DateTime> sortedDates) {
    if (sortedDates.isEmpty) return 0;
    int best = 1;
    int current = 1;
    for (var i = 1; i < sortedDates.length; i++) {
      final diff = sortedDates[i].difference(sortedDates[i - 1]).inDays;
      if (diff <= 30) {
        current++;
        if (current > best) best = current;
      } else {
        current = 1;
      }
    }
    return best;
  }

  static double diversityScore(int unique, int total) {
    if (total == 0) return 0.0;
    return (unique / total).clamp(0.0, 1.0);
  }
}

// ── Reusable mini-widgets ──────────────────────────────────────────────────

class AnalyticsBadgePill extends StatelessWidget {
  final String label;
  final Color color;
  const AnalyticsBadgePill(this.label, {super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class AnalyticsTrendBadge extends StatelessWidget {
  final double change;
  const AnalyticsTrendBadge(this.change, {super.key});

  @override
  Widget build(BuildContext context) {
    final up = change >= 0;
    final color = up ? AnalyticsColors.success : AnalyticsColors.danger;
    final icon = up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        Text(
          '${change.abs().toStringAsFixed(1)}%',
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
