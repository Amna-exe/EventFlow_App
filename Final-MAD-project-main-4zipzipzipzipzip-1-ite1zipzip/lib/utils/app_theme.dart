import 'package:flutter/material.dart';

// ── Warm Minimal SaaS — EventFlow Design System ─────────────────────────────
// Direction: professional · warm · soft · slightly quirky · clean enterprise

// ── Backgrounds ──────────────────────────────────────────────────────────────
const kAppBg         = Color(0xFFFAF7F2);
const kCardBg        = Color(0xFFFFFFFF);
const kBorderColor   = Color(0xFFE9E1D6);

// ── Text ─────────────────────────────────────────────────────────────────────
const kTextPrimary   = Color(0xFF1F1A17);
const kTextSecondary = Color(0xFF6E6258);
const kTextMuted     = Color(0xFFA09489);

// ── Brand accent (warm clay) ──────────────────────────────────────────────────
const kAccent        = Color(0xFFC46A3D);
const kAccentSoft    = Color(0xFFE8C6B0);
const kAccentBg      = Color(0xFFFFF1E8);

// ── Status ───────────────────────────────────────────────────────────────────
const kSuccess       = Color(0xFF3D7A5A);
const kSuccessLight  = Color(0xFFE6F4ED);
const kWarning       = Color(0xFFB7791F);
const kWarningLight  = Color(0xFFFEF3C7);
const kError         = Color(0xFFC24A3A);
const kErrorLight    = Color(0xFFFEE8E6);
const kInfo          = Color(0xFF5A6F8C);
const kInfoLight     = Color(0xFFE8EDF3);

// ── Geometry ─────────────────────────────────────────────────────────────────
const kRadius        = 12.0;
const kRadiusLg      = 16.0;
const kPad           = 20.0;

// ── Typography helpers ────────────────────────────────────────────────────────
const kHeadStyle = TextStyle(
  color: kTextPrimary,
  fontSize: 22,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.5,
  height: 1.3,
);

const kSubheadStyle = TextStyle(
  color: kTextSecondary,
  fontSize: 14,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const kSectionStyle = TextStyle(
  color: kTextPrimary,
  fontSize: 15,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.2,
  height: 1.3,
);

const kBodyStyle = TextStyle(
  color: kTextSecondary,
  fontSize: 13,
  fontWeight: FontWeight.w400,
  height: 1.4,
);

const kMutedStyle = TextStyle(
  color: kTextMuted,
  fontSize: 12,
  fontWeight: FontWeight.w400,
);

// ── Insight tag ───────────────────────────────────────────────────────────────
class InsightTag extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const InsightTag({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 10),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── KPI card ─────────────────────────────────────────────────────────────────
class KpiCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String? subtitle;
  final Color? accentColor;
  final Widget? tag;

  const KpiCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.subtitle,
    this.accentColor,
    this.tag,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? kAccent;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              if (tag != null) tag!,
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              color: kTextPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: kMutedStyle),
          if (subtitle != null) ...[
            const SizedBox(height: 5),
            Text(
              subtitle!,
              style: const TextStyle(
                color: kTextSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────
class AppSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const AppSectionHeader(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: kSectionStyle)),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ── Card container ────────────────────────────────────────────────────────────
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final double? radius;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.borderColor,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(radius ?? kRadius),
        border: Border.all(color: borderColor ?? kBorderColor),
      ),
      child: child,
    );
  }
}

// ── ThemeData factory ─────────────────────────────────────────────────────────
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kAccent,
      brightness: Brightness.light,
    ).copyWith(
      primary: kAccent,
      surface: kCardBg,
      onSurface: kTextPrimary,
    ),
    scaffoldBackgroundColor: kAppBg,

    cardTheme: const CardThemeData(
      color: kCardBg,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kCardBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadius),
        borderSide: const BorderSide(color: kBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadius),
        borderSide: const BorderSide(color: kBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadius),
        borderSide: const BorderSide(color: kAccent, width: 1.5),
      ),
      labelStyle: const TextStyle(color: kTextSecondary),
      hintStyle: const TextStyle(color: kTextMuted),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadius),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: kAccent),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: kCardBg,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: kTextPrimary),
      titleTextStyle: TextStyle(
        color: kTextPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: kBorderColor,
      thickness: 1,
      space: 1,
    ),

    chipTheme: ChipThemeData(
      backgroundColor: kAccentBg,
      labelStyle: const TextStyle(
        color: kAccent,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      side: const BorderSide(color: kAccentSoft),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}
