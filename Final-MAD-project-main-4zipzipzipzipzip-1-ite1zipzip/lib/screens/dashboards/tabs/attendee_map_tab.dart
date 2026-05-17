import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/auth_service.dart';
import '../../../services/venue_service.dart';
import '../../../models/building_model.dart';

// ── Theme ──────────────────────────────────────────────────────────────────
const _kPrimary      = Color(0xFFC46A3D);
const _kPrimaryLight = Color(0xFFFFF1E8);
const _kTextDark     = Color(0xFF1F1A17);
const _kTextMid      = Color(0xFF6E6258);
const _kTextLight    = Color(0xFFA09489);
const _kBorder       = Color(0xFFE9E1D6);
const _kSurface      = Color(0xFFFFFFFF);
const _kSuccess      = Color(0xFF3D7A5A);

const _categoryColors = <String, Color>{
  'Technology':     Color(0xFFC46A3D),
  'Business':       Color(0xFF3D7A5A),
  'Arts & Culture': Color(0xFF8B5E52),
  'Education':      Color(0xFFB7791F),
  'Workshop':       Color(0xFF5A8C6F),
  'Seminar':        Color(0xFF8B5E52),
  'Conference':     Color(0xFF5A6F8C),
  'Networking':     Color(0xFF6E6258),
  'Health':         Color(0xFFC24A3A),
  'Finance':        Color(0xFF3D7A5A),
};

Color _catColor(String c) => _categoryColors[c] ?? _kPrimary;

// ── Widget ─────────────────────────────────────────────────────────────────

class AttendeeMapTab extends StatefulWidget {
  final Set<String> registeredIds;
  final void Function(Map<String, dynamic>) onToggleRegistration;
  final void Function(Map<String, dynamic>) onEventTap;
  final String Function(Map<String, dynamic>) locationLabel;
  final String Function(Map<String, dynamic>) organizerName;

  const AttendeeMapTab({
    super.key,
    required this.registeredIds,
    required this.onToggleRegistration,
    required this.onEventTap,
    required this.locationLabel,
    required this.organizerName,
  });

  @override
  State<AttendeeMapTab> createState() => _AttendeeMapTabState();
}

class _AttendeeMapTabState extends State<AttendeeMapTab> {
  final _auth  = AuthService();
  final _venue = VenueService();
  late final MapController _mapCtrl;
  BuildingModel? _activeBuilding;

  // Nearby Events feature
  double? _userLat;
  double? _userLng;
  double _radiusKm = 10.0;
  bool   _nearbyMode = false;
  bool   _showLocationPicker = false;

  // Pre-set city locations
  static const _cities = <String, (double, double)>{
    'London':     (51.5074, -0.1278),
    'Manchester': (53.4808, -2.2426),
    'Bristol':    (51.4545, -2.5879),
    'Birmingham': (52.4862, -1.8904),
    'Leeds':      (53.8008, -1.5491),
  };

  @override
  void initState() {
    super.initState();
    _mapCtrl = MapController();
  }

  @override
  void dispose() {
    _mapCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  List<BuildingModel> get _mapped =>
      _venue.allBuildings.where((b) => b.hasLocation).toList();

  LatLng get _center {
    if (_userLat != null && _userLng != null && _nearbyMode) {
      return LatLng(_userLat!, _userLng!);
    }
    final m = _mapped;
    if (m.isEmpty) return const LatLng(51.5074, -0.1278);
    final lat = m.map((b) => b.latitude!).reduce((a, b) => a + b) / m.length;
    final lng = m.map((b) => b.longitude!).reduce((a, b) => a + b) / m.length;
    return LatLng(lat, lng);
  }

  List<Map<String, dynamic>> _eventsAtBuilding(BuildingModel building) {
    final roomIds = _venue.roomsForBuilding(building.id).map((r) => r.id).toSet();
    final bookingIds = _auth.allBookings
        .where((bk) => roomIds.contains(bk['roomId']))
        .map((bk) => bk['id'] as String)
        .toSet();
    return _auth.allEvents
        .where((e) =>
            e['status'] == 'published' &&
            bookingIds.contains(e['bookingId']))
        .toList()
      ..sort((a, b) {
        final sa = a['start'] as DateTime?;
        final sb = b['start'] as DateTime?;
        if (sa == null && sb == null) return 0;
        if (sa == null) return 1;
        if (sb == null) return -1;
        return sa.compareTo(sb);
      });
  }

  bool _hasRegisteredEvent(BuildingModel b) {
    final events = _eventsAtBuilding(b);
    return events.any((e) => widget.registeredIds.contains(e['id']));
  }

  // Haversine distance in km
  double _distanceTo(BuildingModel b) {
    if (_userLat == null || _userLng == null) return double.infinity;
    if (!b.hasLocation) return double.infinity;
    const R = 6371.0;
    final dLat = _toRad(b.latitude! - _userLat!);
    final dLng = _toRad(b.longitude! - _userLng!);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(_userLat!)) *
            math.cos(_toRad(b.latitude!)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _toRad(double deg) => deg * math.pi / 180;

  String _fmtDistance(double km) {
    if (km < 1) return '${(km * 1000).round()}m';
    return '${km.toStringAsFixed(1)}km';
  }

  List<BuildingModel> get _filteredMapped {
    var venues = _mapped;
    if (_nearbyMode && _userLat != null && _userLng != null) {
      venues = venues
          .where((b) => _distanceTo(b) <= _radiusKm)
          .toList()
        ..sort((a, b) => _distanceTo(a).compareTo(_distanceTo(b)));
    }
    return venues;
  }

  Future<void> _openDirections(BuildingModel b) async {
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=${b.latitude},${b.longitude}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _fmtDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final buildings = _venue.allBuildings;
    final mapped    = _mapped;

    if (buildings.isEmpty) return _emptyState('No venues available yet.');
    if (mapped.isEmpty)    return _emptyState('No venue locations set yet.');

    final filtered = _filteredMapped;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Nearby Events Panel ─────────────────────────────
        _nearbyPanel(),
        const SizedBox(height: 12),

        // ── Legend ──────────────────────────────────────────
        _legend(),
        const SizedBox(height: 12),

        // ── Map ─────────────────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 340,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapCtrl,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: _nearbyMode ? 11 : 12,
                    onTap: (_, __) => setState(() => _activeBuilding = null),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.eventflow.app',
                    ),
                    // User location marker
                    if (_userLat != null && _userLng != null && _nearbyMode)
                      MarkerLayer(markers: [
                        Marker(
                          point: LatLng(_userLat!, _userLng!),
                          width: 36,
                          height: 36,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _kPrimary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                    color: _kPrimary.withOpacity(0.4),
                                    blurRadius: 8),
                              ],
                            ),
                            child: const Icon(Icons.my_location,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ]),
                    MarkerLayer(
                      markers: mapped.map((b) {
                        final isActive = _activeBuilding?.id == b.id;
                        final hasReg   = _hasRegisteredEvent(b);
                        final events   = _eventsAtBuilding(b);
                        final dist     = _distanceTo(b);
                        final inRange  = !_nearbyMode ||
                            dist <= _radiusKm ||
                            _userLat == null;

                        return Marker(
                          point: LatLng(b.latitude!, b.longitude!),
                          width: isActive ? 60 : 48,
                          height: isActive ? 60 : 48,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _activeBuilding = b);
                              _mapCtrl.move(
                                  LatLng(b.latitude!, b.longitude!), 15);
                            },
                            child: AnimatedContainer(
                              duration:
                                  const Duration(milliseconds: 200),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: isActive ? 40 : 32,
                                    height: isActive ? 40 : 32,
                                    decoration: BoxDecoration(
                                      color: hasReg
                                          ? const Color(0xFF1A1A1A)
                                          : inRange
                                              ? Colors.white
                                              : Colors.grey.shade200,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: inRange
                                            ? const Color(0xFF1A1A1A)
                                            : Colors.grey,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withAlpha(40),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.location_city_outlined,
                                      size: isActive ? 20 : 15,
                                      color: hasReg
                                          ? Colors.white
                                          : inRange
                                              ? const Color(0xFF1A1A1A)
                                              : Colors.grey,
                                    ),
                                  ),
                                  if (events.isNotEmpty)
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF2D2D2D),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text('${events.length}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                              )),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),

                // Active building popup
                if (_activeBuilding != null)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: _buildingPopup(_activeBuilding!),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Venue list ──────────────────────────────────────
        Row(
          children: [
            Text(
              _nearbyMode && _userLat != null
                  ? 'Venues within ${_radiusKm.toInt()}km'
                  : 'All Venues',
              style: const TextStyle(
                color: _kTextDark,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            if (_nearbyMode && _userLat != null)
              Text('${filtered.length} found',
                  style: const TextStyle(
                      color: _kTextLight, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 10),

        if (filtered.isEmpty && _nearbyMode)
          _noNearbyState()
        else
          ...filtered.map((b) => _venueListTile(b)),
      ],
    );
  }

  // ── Nearby events panel ────────────────────────────────────────────────

  Widget _nearbyPanel() {
    return Container(
      decoration: BoxDecoration(
        color: _nearbyMode ? _kPrimary.withOpacity(0.05) : _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _nearbyMode
              ? _kPrimary.withOpacity(0.3)
              : _kBorder,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _nearbyMode ? _kPrimary : const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.near_me_outlined,
                    size: 18,
                    color: _nearbyMode ? Colors.white : _kTextMid,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nearby Events',
                        style: TextStyle(
                          color: _nearbyMode ? _kPrimary : _kTextDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _nearbyMode && _userLat != null
                            ? 'Showing venues within ${_radiusKm.toInt()}km'
                            : 'Discover events near your location',
                        style: const TextStyle(
                            color: _kTextLight, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _nearbyMode,
                  activeColor: _kPrimary,
                  onChanged: (v) {
                    setState(() {
                      _nearbyMode = v;
                      if (v) _showLocationPicker = true;
                    });
                  },
                ),
              ],
            ),
          ),
          if (_nearbyMode) ...[
            const Divider(height: 1, color: Color(0xFFE8E8E8)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // City quick-select
                  const Text('Quick select city:',
                      style: TextStyle(
                          color: _kTextMid, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _cities.entries.map((entry) {
                        final (lat, lng) = entry.value;
                        final isSelected = _userLat == lat && _userLng == lng;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _userLat = lat;
                              _userLng = lng;
                              _showLocationPicker = false;
                            });
                            _mapCtrl.move(LatLng(lat, lng), 11);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected ? _kPrimary : _kSurface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? _kPrimary
                                    : _kBorder,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_city_outlined,
                                    size: 12,
                                    color: isSelected
                                        ? Colors.white
                                        : _kTextMid),
                                const SizedBox(width: 5),
                                Text(entry.key,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : _kTextDark,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    )),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Radius slider
                  Row(
                    children: [
                      const Icon(Icons.radar_outlined,
                          size: 14, color: _kTextMid),
                      const SizedBox(width: 6),
                      Text('Search radius: ${_radiusKm.toInt()}km',
                          style: const TextStyle(
                              color: _kTextMid,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text(
                        _userLat != null
                            ? '${_filteredMapped.length} venue${_filteredMapped.length != 1 ? 's' : ''} found'
                            : 'Select a city above',
                        style: const TextStyle(
                            color: _kTextLight, fontSize: 11),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 8),
                      overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 16),
                      activeTrackColor: _kPrimary,
                      thumbColor: _kPrimary,
                      inactiveTrackColor: _kBorder,
                      overlayColor: _kPrimary.withOpacity(0.12),
                    ),
                    child: Slider(
                      value: _radiusKm,
                      min: 5,
                      max: 50,
                      divisions: 9,
                      onChanged: (v) =>
                          setState(() => _radiusKm = v),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('5km',
                          style: TextStyle(
                              color: _kTextLight, fontSize: 10)),
                      const Text('25km',
                          style: TextStyle(
                              color: _kTextLight, fontSize: 10)),
                      const Text('50km',
                          style: TextStyle(
                              color: _kTextLight, fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Legend ────────────────────────────────────────────────────────────

  Widget _legend() {
    return Row(
      children: [
        _legendDot(const Color(0xFF1A1A1A), 'Has registered event'),
        const SizedBox(width: 16),
        _legendDot(Colors.white, 'No registered events',
            border: const Color(0xFF1A1A1A)),
        if (_nearbyMode && _userLat != null) ...[
          const SizedBox(width: 16),
          _legendDot(_kPrimary, 'Your location'),
        ],
      ],
    );
  }

  Widget _legendDot(Color fill, String label, {Color? border}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border:
                border != null ? Border.all(color: border, width: 1.5) : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(label,
            style:
                const TextStyle(color: Color(0xFF6B6B6B), fontSize: 11)),
      ],
    );
  }

  // ── Building popup ────────────────────────────────────────────────────

  Widget _buildingPopup(BuildingModel b) {
    final events = _eventsAtBuilding(b);
    final dist   = _distanceTo(b);
    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(30),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                const Icon(Icons.location_city_outlined,
                    size: 18, color: Color(0xFF1A1A1A)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF1A1A1A))),
                      Row(
                        children: [
                          Expanded(
                            child: Text(b.address,
                                style: const TextStyle(
                                    color: Color(0xFF6B6B6B), fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (!dist.isInfinite) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _kPrimary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(_fmtDistance(dist),
                                  style: const TextStyle(
                                      color: _kPrimary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _openDirections(b),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.directions_outlined,
                                size: 13, color: Colors.white),
                            SizedBox(width: 3),
                            Text('Directions',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _activeBuilding = null),
                      child: const Icon(Icons.close,
                          size: 18, color: Color(0xFF9E9E9E)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text('No events at this venue.',
                  style: TextStyle(
                      color: Color(0xFF9E9E9E), fontSize: 12)),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${events.length} event${events.length != 1 ? 's' : ''} here',
                      style: const TextStyle(
                          color: Color(0xFF6B6B6B),
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ...events.map((e) => _popupEventRow(e)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _popupEventRow(Map<String, dynamic> e) {
    final registered = widget.registeredIds.contains(e['id']);
    final cat   = (e['category'] as String? ?? '');
    final start = e['start'] as DateTime?;
    final end   = e['end']   as DateTime?;

    return GestureDetector(
      onTap: () {
        setState(() => _activeBuilding = null);
        widget.onEventTap(e);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: registered
              ? const Color(0xFFF5F5F5)
              : const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: registered
                ? const Color(0xFF1A1A1A)
                : const Color(0xFFE8E8E8),
            width: registered ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 3, height: 36,
              decoration: BoxDecoration(
                  color: _catColor(cat),
                  borderRadius: BorderRadius.circular(99)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e['title'] as String? ?? '',
                      style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontWeight: FontWeight.w600,
                          fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                  if (start != null)
                    Text(
                      '${_fmtDate(start)}  ${_fmtTime(start)}'
                      '${end != null ? ' – ${_fmtTime(end)}' : ''}',
                      style: const TextStyle(
                          color: Color(0xFF6B6B6B), fontSize: 11),
                    ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => widget.onToggleRegistration(e),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: registered
                      ? const Color(0xFF1A1A1A)
                      : const Color(0xFFEEEEEE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  registered ? '✓' : '+',
                  style: TextStyle(
                    color: registered
                        ? Colors.white
                        : const Color(0xFF1A1A1A),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _venueListTile(BuildingModel b) {
    final events = _eventsAtBuilding(b);
    final hasReg = _hasRegisteredEvent(b);
    final dist   = _distanceTo(b);

    return GestureDetector(
      onTap: () {
        setState(() => _activeBuilding = b);
        _mapCtrl.move(LatLng(b.latitude!, b.longitude!), 15);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasReg
                ? const Color(0xFF1A1A1A)
                : _kBorder,
            width: hasReg ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: hasReg
                    ? const Color(0xFF1A1A1A)
                    : const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.location_city_outlined,
                size: 18,
                color: hasReg ? Colors.white : const Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.name,
                      style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  Text(b.address,
                      style: const TextStyle(
                          color: Color(0xFF6B6B6B), fontSize: 11),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${events.length} event${events.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                        color: Color(0xFF9E9E9E), fontSize: 11)),
                if (!dist.isInfinite)
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _kPrimary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _fmtDistance(dist),
                      style: const TextStyle(
                          color: _kPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700),
                    ),
                  )
                else if (hasReg)
                  const Text('Registered',
                      style: TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                color: Color(0xFFCCCCCC), size: 18),
          ],
        ),
      ),
    );
  }

  // ── Empty states ──────────────────────────────────────────────────────

  Widget _noNearbyState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _kPrimaryLight.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kPrimary.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          const Icon(Icons.near_me_disabled_outlined,
              size: 40, color: _kPrimary),
          const SizedBox(height: 12),
          Text(
            _userLat == null
                ? 'Select a city above to find nearby venues.'
                : 'No venues found within ${_radiusKm.toInt()}km.\nTry increasing the search radius.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Color(0xFF475569), fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String msg) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 42, color: Color(0xFFD0D0D0)),
            const SizedBox(height: 10),
            Text(msg,
                style: const TextStyle(
                    color: Color(0xFF9E9E9E), fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
