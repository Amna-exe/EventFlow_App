import 'dart:math' as math;
import 'package:flutter/material.dart';

// ── Banner colour themes ──────────────────────────────────────────────────────

const List<List<Color>> _bannerThemes = [
  [Color(0xFF1A237E), Color(0xFF3949AB), Color(0xFFFFD54F)],
  [Color(0xFF4A148C), Color(0xFF7B1FA2), Color(0xFFF06292)],
  [Color(0xFF004D40), Color(0xFF00796B), Color(0xFF80CBC4)],
  [Color(0xFFBF360C), Color(0xFFE64A19), Color(0xFFFFCC02)],
  [Color(0xFF1B5E20), Color(0xFF388E3C), Color(0xFFA5D6A7)],
  [Color(0xFF263238), Color(0xFF455A64), Color(0xFFCFD8DC)],
  [Color(0xFF880E4F), Color(0xFFC2185B), Color(0xFFF8BBD0)],
  [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFFBBDEFB)],
];

int themeCount = _bannerThemes.length;

// ── Decorative painter ────────────────────────────────────────────────────────

class _BannerPatternPainter extends CustomPainter {
  final Color color;
  _BannerPatternPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const gap = 36.0;
    for (double x = -size.height; x < size.width + size.height; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
    }

    final circlePaint = Paint()
      ..color = color.withOpacity(0.05)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
        Offset(size.width * 0.85, size.height * 0.15), size.width * 0.28, circlePaint);
    canvas.drawCircle(
        Offset(size.width * 0.1, size.height * 0.85), size.width * 0.18, circlePaint);
  }

  @override
  bool shouldRepaint(_BannerPatternPainter old) => old.color != color;
}

// ── Tier colours ─────────────────────────────────────────────────────────────

Color _tierColor(String tier) {
  switch (tier.toLowerCase()) {
    case 'gold':
      return const Color(0xFFFFD700);
    case 'silver':
      return const Color(0xFFB0BEC5);
    case 'bronze':
      return const Color(0xFFCD7F32);
    default:
      return const Color(0xFF90CAF9);
  }
}

// ── Public widget ─────────────────────────────────────────────────────────────

class EventBannerWidget extends StatelessWidget {
  const EventBannerWidget({
    super.key,
    required this.title,
    this.date,
    this.venueName = '',
    this.speakers = const [],
    this.sponsors = const [],
    this.themeIndex = 0,
    this.height = 200,
  });

  final String title;
  final DateTime? date;
  final String venueName;
  final List<Map<String, dynamic>> speakers;
  final List<Map<String, dynamic>> sponsors;
  final int themeIndex;
  final double height;

  static String _fmt(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final idx = themeIndex.clamp(0, _bannerThemes.length - 1);
    final colors = _bannerThemes[idx];
    final dark = colors[0];
    final mid = colors[1];
    final accent = colors[2];

    final displayTitle =
        title.trim().isEmpty ? 'Your Event Title' : title.trim();
    final dateStr = date != null ? _fmt(date!) : 'Date TBD';
    final venueStr =
        venueName.trim().isEmpty ? 'Venue TBD' : venueName.trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [dark, mid],
                ),
              ),
            ),

            // Diagonal stripe pattern
            CustomPaint(painter: _BannerPatternPainter(accent)),

            // Accent bar on the left
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 5, color: accent),
            ),

            // EventFlow watermark top-right
            Positioned(
              top: 12,
              right: 14,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'EventFlow',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category / accent chip (use speakers role as category hint)
                  if (speakers.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: accent.withOpacity(0.5)),
                      ),
                      child: Text(
                        speakers.length == 1
                            ? 'Featuring ${speakers.first['name'] ?? ''}'
                            : '${speakers.length} Featured Speakers',
                        style: TextStyle(
                          color: accent,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),

                  // Title
                  Flexible(
                    child: Text(
                      displayTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Date + Venue row
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 11, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        dateStr,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.location_on_outlined,
                          size: 11, color: Colors.white70),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          venueStr,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Speakers row
                  if (speakers.isNotEmpty) ...[
                    Row(
                      children: [
                        ...speakers.take(4).toList().asMap().entries.map((entry) {
                          final i = entry.key;
                          final s = entry.value;
                          final name = (s['name'] as String? ?? '');
                          final initial =
                              name.isNotEmpty ? name[0].toUpperCase() : '?';
                          return Padding(
                            padding: EdgeInsets.only(left: i == 0 ? 0 : -6),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                                border: Border.all(color: dark, width: 1.5),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                initial,
                                style: TextStyle(
                                  color: dark,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          );
                        }),
                        if (speakers.length > 4) ...[
                          const SizedBox(width: 6),
                          Text(
                            '+${speakers.length - 4} more',
                            style: TextStyle(
                                color: accent, fontSize: 10),
                          ),
                        ] else ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              speakers
                                  .take(2)
                                  .map((s) => s['name'] ?? '')
                                  .join(', '),
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Sponsors row
                  if (sponsors.isNotEmpty)
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: sponsors.take(5).map((sp) {
                        final tier = sp['tier'] as String? ?? 'Partner';
                        final name = sp['name'] as String? ?? '';
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: _tierColor(tier).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: _tierColor(tier).withOpacity(0.5)),
                          ),
                          child: Text(
                            name,
                            style: TextStyle(
                              color: _tierColor(tier),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
