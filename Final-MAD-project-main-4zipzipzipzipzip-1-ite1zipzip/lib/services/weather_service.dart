import 'dart:convert';
import 'package:http/http.dart' as http;

// ── OpenWeather API key ────────────────────────────────────────────────────
// Replace with your own key from https://openweathermap.org/api
// Free tier supports 5-day / 3-hour forecast (forecast endpoint used below).
const _kApiKey = 'd2ee8397a27ef599a54c28e34f6633b7';

// ── Data model ─────────────────────────────────────────────────────────────

enum WeatherCondition { clear, cloudy, rain, storm, snow, unknown }

class WeatherResult {
  final double tempC;
  final WeatherCondition condition;
  final int precipPct;
  final String description;
  final String city;
  final DateTime fetchedAt;

  const WeatherResult({
    required this.tempC,
    required this.condition,
    required this.precipPct,
    required this.description,
    required this.city,
    required this.fetchedAt,
  });

  // ── Rule-based helpers ─────────────────────────────────────────────────

  bool get isHighRainRisk => precipPct > 60;
  bool get isMediumRainRisk => precipPct > 30 && precipPct <= 60;
  bool get isStorm => condition == WeatherCondition.storm;
  bool get isExtremeHeat => tempC > 36;
  bool get isExtremeCold => tempC < 2;

  String get conditionLabel {
    switch (condition) {
      case WeatherCondition.clear: return 'Clear';
      case WeatherCondition.cloudy: return 'Cloudy';
      case WeatherCondition.rain: return 'Rainy';
      case WeatherCondition.storm: return 'Storm';
      case WeatherCondition.snow: return 'Snow';
      case WeatherCondition.unknown: return 'Unknown';
    }
  }

  String get conditionEmoji {
    switch (condition) {
      case WeatherCondition.clear: return '☀️';
      case WeatherCondition.cloudy: return '⛅';
      case WeatherCondition.rain: return '🌧️';
      case WeatherCondition.storm: return '⛈️';
      case WeatherCondition.snow: return '❄️';
      case WeatherCondition.unknown: return '🌡️';
    }
  }

  /// Indoor / outdoor recommendation
  String get venueRecommendation {
    if (isStorm) return 'Recommended: Indoor only — storm conditions forecast';
    if (isHighRainRisk) {
      return 'Recommended: Indoor setup — ${precipPct}% rain probability';
    }
    if (isMediumRainRisk) {
      return 'Consider covered outdoor space — ${precipPct}% chance of rain';
    }
    if (isExtremeHeat) {
      return 'Recommended: Indoor — extreme heat (${tempC.toStringAsFixed(0)}°C)';
    }
    if (isExtremeCold) {
      return 'Recommended: Indoor — cold temperatures (${tempC.toStringAsFixed(0)}°C)';
    }
    return 'Outdoor conditions are favourable — $conditionLabel expected';
  }

  /// AI-style plain-language insight
  String get aiInsight {
    if (isStorm) return 'Severe weather expected. High risk of event disruption.';
    if (isHighRainRisk) return 'Weather may significantly affect outdoor attendance.';
    if (isMediumRainRisk) return 'Moderate rain risk — have a contingency plan ready.';
    if (isExtremeHeat) return 'Heat may reduce comfort. Ensure shade and hydration facilities.';
    if (isExtremeCold) return 'Cold temperatures may lower turnout. Plan for heating.';
    if (condition == WeatherCondition.clear && tempC >= 18 && tempC <= 26) {
      return 'Peak comfort conditions expected — low weather attendance risk.';
    }
    return 'Weather outlook is acceptable. Monitor closer to event date.';
  }

  /// Whether a risk warning banner should be shown
  bool get showRiskWarning => isHighRainRisk || isStorm || isExtremeHeat || isExtremeCold;

  String get riskWarningText {
    if (isStorm) return 'Weather Risk: Storm forecast on event date.';
    if (isHighRainRisk) return 'Weather Risk: ${precipPct}% rain probability on event date.';
    if (isExtremeHeat) return 'Weather Risk: Extreme heat (${tempC.toStringAsFixed(0)}°C) forecast.';
    if (isExtremeCold) return 'Weather Risk: Near-freezing temperatures (${tempC.toStringAsFixed(0)}°C) forecast.';
    return '';
  }
}

// ── Cache entry ────────────────────────────────────────────────────────────

class _CacheEntry {
  final WeatherResult result;
  final DateTime cachedAt;
  _CacheEntry(this.result) : cachedAt = DateTime.now();
  bool get isStale =>
      DateTime.now().difference(cachedAt).inMinutes > 30;
}

// ── Service ────────────────────────────────────────────────────────────────

class WeatherService {
  WeatherService._();
  static final WeatherService instance = WeatherService._();

  final Map<String, _CacheEntry> _cache = {};

  static bool get hasApiKey =>
      _kApiKey.isNotEmpty && _kApiKey != 'YOUR_OPENWEATHER_API_KEY';

  /// Extract a usable city name from a building address string.
  /// E.g. "123 Baker St, London, UK" → "London"
  static String cityFromAddress(String address) {
    final parts = address.split(',').map((s) => s.trim()).toList();
    if (parts.length >= 2) {
      // second-to-last part is usually city
      final candidate = parts[parts.length >= 3 ? parts.length - 2 : 1];
      if (candidate.isNotEmpty) return candidate;
    }
    return parts.isNotEmpty ? parts.last : address;
  }

  /// Fetch a weather result for a given [city] on a given [date].
  /// Returns null if API key missing, no internet, or error.
  Future<WeatherResult?> fetchForDate(String city, DateTime date) async {
    if (!hasApiKey) return _mockResult(city, date);

    final cacheKey = '${city.toLowerCase()}_${date.toIso8601String().substring(0, 10)}';
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isStale) return cached.result;

    try {
      final uri = Uri.parse(
        'https://api.openweathermap.org/data/2.5/forecast'
        '?q=${Uri.encodeComponent(city)}'
        '&appid=$_kApiKey'
        '&units=metric'
        '&cnt=40',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final list = json['list'] as List<dynamic>;

      // Find the forecast slot closest to the event date's daytime (noon)
      final target = DateTime(date.year, date.month, date.day, 12);
      Map<String, dynamic>? best;
      Duration bestDiff = const Duration(days: 999);
      for (final item in list) {
        final dt = DateTime.fromMillisecondsSinceEpoch(
            (item['dt'] as int) * 1000, isUtc: true).toLocal();
        final diff = (dt.difference(target)).abs();
        if (diff < bestDiff) {
          bestDiff = diff;
          best = item as Map<String, dynamic>;
        }
      }
      if (best == null) return null;

      final result = _parseEntry(best, city);
      _cache[cacheKey] = _CacheEntry(result);
      return result;
    } catch (_) {
      return null;
    }
  }

  static WeatherResult _parseEntry(Map<String, dynamic> entry, String city) {
    final main = entry['main'] as Map<String, dynamic>;
    final weatherList = entry['weather'] as List<dynamic>;
    final weatherId =
        weatherList.isNotEmpty ? (weatherList.first as Map)['id'] as int : 800;
    final pop = ((entry['pop'] as num?) ?? 0.0) * 100;
    final tempC = (main['temp'] as num).toDouble();
    final desc =
        ((weatherList.firstOrNull as Map?)?['description'] as String? ?? '')
            .capitalised;

    WeatherCondition cond;
    if (weatherId >= 200 && weatherId < 300) {
      cond = WeatherCondition.storm;
    } else if (weatherId >= 300 && weatherId < 600) {
      cond = WeatherCondition.rain;
    } else if (weatherId >= 600 && weatherId < 700) {
      cond = WeatherCondition.snow;
    } else if (weatherId >= 801 && weatherId <= 804) {
      cond = WeatherCondition.cloudy;
    } else if (weatherId == 800) {
      cond = WeatherCondition.clear;
    } else {
      cond = WeatherCondition.unknown;
    }

    return WeatherResult(
      tempC: tempC,
      condition: cond,
      precipPct: pop.round(),
      description: desc,
      city: city,
      fetchedAt: DateTime.now(),
    );
  }

  /// Fallback mock when no API key is configured — gives a
  /// deterministic-ish result so the UI is still exercised.
  static WeatherResult _mockResult(String city, DateTime date) {
    final dayOfYear = date.dayOfYear;
    final conditions = WeatherCondition.values;
    final cond = conditions[dayOfYear % conditions.length];
    final pop = (dayOfYear * 7) % 100;
    final tempC = 14 + (dayOfYear % 16).toDouble();
    return WeatherResult(
      tempC: tempC,
      condition: cond,
      precipPct: pop,
      description: cond.name.capitalised,
      city: city,
      fetchedAt: DateTime.now(),
    );
  }
}

extension on String {
  String get capitalised =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

extension on DateTime {
  int get dayOfYear {
    final start = DateTime(year, 1, 1);
    return difference(start).inDays + 1;
  }
}
