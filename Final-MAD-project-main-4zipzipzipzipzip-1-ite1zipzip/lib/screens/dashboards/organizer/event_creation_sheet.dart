import 'dart:async';
import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../services/weather_service.dart';
import 'event_banner_widget.dart';

// ── Theme constants (match organizer dashboard) ───────────────────────────────

const _white = Color(0xFFFFFFFF);
const _border = Color(0xFFE9E1D6);
const _ink = Color(0xFF1F1A17);
const _muted = Color(0xFF6E6258);
const _accent = Color(0xFFC46A3D);
const _bg = Color(0xFFFAF7F2);

// ── Tier options ──────────────────────────────────────────────────────────────

const _tierOptions = ['Gold', 'Silver', 'Bronze', 'Partner'];

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmt(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}

String _fmtTime(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

String _fmtDate(DateTime dt) => '${_fmt(dt)}, ${_fmtTime(dt)}';

// ── Main Sheet ────────────────────────────────────────────────────────────────

class EventCreationSheet extends StatefulWidget {
  const EventCreationSheet({
    super.key,
    this.existing,
    required this.onSaved,
  });

  final Map<String, dynamic>? existing;
  final void Function(String message) onSaved;

  @override
  State<EventCreationSheet> createState() => _EventCreationSheetState();
}

class _EventCreationSheetState extends State<EventCreationSheet>
    with SingleTickerProviderStateMixin {
  final _auth = AuthService();

  // Controllers
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _attendeesCtrl = TextEditingController();

  // Dates
  late DateTime _start;
  late DateTime _end;

  // Speakers: [{name, role, image}]
  final List<Map<String, dynamic>> _speakers = [];

  // Sponsors: [{name, tier, logo}]
  final List<Map<String, dynamic>> _sponsors = [];

  // Venue
  String? _selectedRoomId;
  String? _selectedBuildingId;
  String _selectedVenueName = '';
  List<Map<String, dynamic>> _venueOptions = [];

  // Banner
  int _bannerTheme = 0;
  bool _bannerExpanded = true;

  // Weather
  WeatherResult? _weather;
  bool _weatherLoading = false;
  String _weatherCity = '';

  // Validation
  final Map<String, String?> _errors = {};
  bool _venueRequired = false;

  // Autosave
  Timer? _autosaveTimer;
  String _autosaveLabel = '';
  bool _isDirty = false;

  // Sections expand state
  bool _speakerExpanded = true;
  bool _sponsorExpanded = true;
  bool _venueExpanded = true;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _start = e != null
        ? (e['start'] as DateTime)
        : DateTime.now().add(const Duration(days: 7, hours: 1));
    _end = e != null
        ? (e['end'] as DateTime)
        : _start.add(const Duration(hours: 3));

    _titleCtrl.text = (e?['title'] as String?) ?? '';
    _descCtrl.text = (e?['description'] as String?) ?? '';
    _categoryCtrl.text = (e?['category'] as String?) ?? '';
    _attendeesCtrl.text =
        ((e?['expectedAttendees'] as int?) ?? 50).toString();

    // Load existing speakers/sponsors/venue
    if (e != null) {
      final sp = e['speakers'];
      if (sp is List) {
        for (final s in sp) {
          if (s is Map) _speakers.add(Map<String, dynamic>.from(s));
        }
      }
      final spon = e['sponsors'];
      if (spon is List) {
        for (final s in spon) {
          if (s is Map) _sponsors.add(Map<String, dynamic>.from(s));
        }
      }
      _selectedRoomId = e['venueRoomId'] as String?;
      _selectedBuildingId = e['venueBuildingId'] as String?;
      _bannerTheme = (e['bannerThemeIndex'] as int?) ?? 0;
      _selectedVenueName = _resolveVenueName();
    }

    _titleCtrl.addListener(_onFormChanged);
    _descCtrl.addListener(_onFormChanged);
    _categoryCtrl.addListener(_onFormChanged);
    _attendeesCtrl.addListener(_onFormChanged);

    _loadVenueOptions();
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _categoryCtrl.dispose();
    _attendeesCtrl.dispose();
    // Dismiss any conflict banner raised by this sheet
    if (mounted) ScaffoldMessenger.of(context).clearMaterialBanners();
    super.dispose();
  }

  // ── Venue helpers ─────────────────────────────────────────

  String _resolveVenueName() {
    if (_selectedRoomId == null) return '';
    final rooms = _auth.allRooms.where((r) => r['id'] == _selectedRoomId);
    if (rooms.isEmpty) return '';
    final room = rooms.first;
    final buildings = _auth.allBuildings
        .where((b) => b['id'] == room['buildingId']);
    if (buildings.isEmpty) return room['name'] as String? ?? '';
    return '${buildings.first['name']} · ${room['name']}';
  }

  void _loadVenueOptions() {
    final allRooms = _auth.allRooms;
    final allBuildings = _auth.allBuildings;
    final allBookings = _auth.allBookings;

    final options = <Map<String, dynamic>>[];

    for (final room in allRooms) {
      final roomId = room['id'] as String;
      final buildingId = room['buildingId'] as String?;
      final building = allBuildings.firstWhere(
        (b) => b['id'] == buildingId,
        orElse: () => <String, dynamic>{},
      );
      if (building.isEmpty) continue;

      // Check if booked for our event window
      final isBooked = allBookings.any((b) {
        if (b['roomId'] != roomId) return false;
        if (b['status'] == 'cancelled') return false;
        // Exclude current event's own booking
        if (_isEdit &&
            b['id'] == (widget.existing!['bookingId'] as String?)) return false;
        final bStart = b['start'] as DateTime?;
        final bEnd = b['end'] as DateTime?;
        if (bStart == null || bEnd == null) return false;
        return _start.isBefore(bEnd) && bStart.isBefore(_end);
      });

      options.add({
        'room': room,
        'building': building,
        'isBooked': isBooked,
      });
    }

    setState(() => _venueOptions = options);
    _fetchWeather();
  }

  // ── Weather ───────────────────────────────────────────────

  Future<void> _fetchWeather() async {
    if (_selectedRoomId == null) {
      setState(() { _weather = null; _weatherLoading = false; });
      return;
    }
    // Resolve city from the selected building's address
    final roomEntry = _venueOptions.firstWhere(
      (v) => (v['room'] as Map)['id'] == _selectedRoomId,
      orElse: () => <String, dynamic>{},
    );
    if (roomEntry.isEmpty) return;
    final address =
        (roomEntry['building'] as Map)['address'] as String? ?? '';
    final city = WeatherService.cityFromAddress(address);
    if (city == _weatherCity &&
        _weather != null &&
        _start.difference(_weather!.fetchedAt).inHours.abs() < 1) {
      return; // still fresh
    }
    setState(() { _weatherLoading = true; _weatherCity = city; });
    final result =
        await WeatherService.instance.fetchForDate(city, _start);
    if (mounted) setState(() { _weather = result; _weatherLoading = false; });
  }

  // ── Autosave ──────────────────────────────────────────────

  void _onFormChanged() {
    if (!_isDirty) setState(() => _isDirty = true);
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(seconds: 2), _autosaveDraft);
  }

  void _autosaveDraft() {
    if (!mounted) return;
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    final err = _auth.upsertOrganizerEvent(
      eventId: _isEdit ? widget.existing!['id'] as String : null,
      title: title,
      description: _descCtrl.text,
      category: _categoryCtrl.text,
      start: _start,
      end: _end,
      expectedAttendees: int.tryParse(_attendeesCtrl.text) ?? 0,
      status: 'draft',
      speakers: _speakers,
      sponsors: _sponsors,
      venueRoomId: _selectedRoomId,
      venueBuildingId: _selectedBuildingId,
      bannerThemeIndex: _bannerTheme,
    );
    if (err == null && mounted) {
      setState(() {
        _autosaveLabel = 'Draft saved';
        _isDirty = false;
      });
      Timer(const Duration(seconds: 3),
          () => mounted ? setState(() => _autosaveLabel = '') : null);
    }
  }

  // ── Validation ────────────────────────────────────────────

  bool _validate({required bool publishing}) {
    final newErrors = <String, String?>{};
    if (_titleCtrl.text.trim().isEmpty) {
      newErrors['title'] = 'Event title is required.';
    }
    if (!_end.isAfter(_start)) {
      newErrors['end'] = 'End time must be after start time.';
    }
    final attendees = int.tryParse(_attendeesCtrl.text) ?? 0;
    if (attendees <= 0) {
      newErrors['attendees'] = 'Must be greater than 0.';
    }
    if (publishing && _selectedRoomId == null) {
      newErrors['venue'] = 'A venue is required to publish this event.';
      _venueRequired = true;
      if (!_venueExpanded) setState(() => _venueExpanded = true);
    }
    setState(() => _errors.addAll(newErrors));
    return newErrors.isEmpty;
  }

  // ── Submit ────────────────────────────────────────────────

  void _submit({required String status}) {
    final publishing = status == 'published';
    if (!_validate(publishing: publishing)) return;

    final err = _auth.upsertOrganizerEvent(
      eventId: _isEdit ? widget.existing!['id'] as String : null,
      title: _titleCtrl.text,
      description: _descCtrl.text,
      category: _categoryCtrl.text,
      start: _start,
      end: _end,
      expectedAttendees: int.tryParse(_attendeesCtrl.text) ?? 0,
      status: status,
      speakers: _speakers,
      sponsors: _sponsors,
      venueRoomId: _selectedRoomId,
      venueBuildingId: _selectedBuildingId,
      bannerThemeIndex: _bannerTheme,
    );

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }

    Navigator.pop(context);
    widget.onSaved(
        _isEdit ? 'Event updated.' : (publishing ? 'Event published.' : 'Draft saved.'));
  }

  // ── Section helpers ───────────────────────────────────────

  Widget _sectionHeader(String title, IconData icon,
      {bool expanded = true, VoidCallback? onToggle}) {
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 14, color: _accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ),
            if (onToggle != null)
              Icon(
                expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: _muted,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
    String? errorKey,
    String? hint,
  }) {
    final error = errorKey != null ? _errors[errorKey] : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          onChanged: (_) {
            if (errorKey != null && _errors[errorKey] != null) {
              setState(() => _errors.remove(errorKey));
            }
          },
          style: const TextStyle(color: _ink, fontSize: 14),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            hintStyle: const TextStyle(color: _muted, fontSize: 13),
            labelStyle: TextStyle(
                color: error != null ? Colors.redAccent : _muted, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF7F7F7),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: error != null ? Colors.redAccent : _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: error != null ? Colors.redAccent : _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: error != null ? Colors.redAccent : _ink,
                  width: 1.5),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.error_outline,
                  size: 12, color: Colors.redAccent),
              const SizedBox(width: 4),
              Text(error,
                  style: const TextStyle(
                      color: Colors.redAccent, fontSize: 11)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _dtTile({
    required String label,
    required DateTime dt,
    required void Function(DateTime) onPicked,
    DateTime? firstDate,
    String? errorKey,
  }) {
    final error = errorKey != null ? _errors[errorKey] : null;
    return GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: dt,
          firstDate: firstDate ?? DateTime.now(),
          lastDate: DateTime(DateTime.now().year + 3),
        );
        if (!mounted || d == null) return;
        final t = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: dt.hour, minute: dt.minute),
        );
        if (!mounted || t == null) return;
        onPicked(
            DateTime(d.year, d.month, d.day, t.hour, t.minute));
        _loadVenueOptions();
        _onFormChanged();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: error != null ? Colors.redAccent : _border),
        ),
        child: Row(
          children: [
            Text('$label: ',
                style: const TextStyle(
                    color: _muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            Expanded(
              child: Text(_fmtDate(dt),
                  style: const TextStyle(
                      color: _ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.edit_calendar_outlined,
                size: 16, color: _muted),
          ],
        ),
      ),
    );
  }

  // ── Speakers section ──────────────────────────────────────

  Widget _buildSpeakersSection() {
    return Column(
      children: [
        _sectionHeader(
          'Speakers',
          Icons.mic_none_outlined,
          expanded: _speakerExpanded,
          onToggle: () => setState(() => _speakerExpanded = !_speakerExpanded),
        ),
        AnimatedCrossFade(
          firstChild: _speakerBody(),
          secondChild: const SizedBox.shrink(),
          crossFadeState: _speakerExpanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _speakerBody() {
    return Column(
      children: [
        ..._speakers.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          return _speakerRow(i, s);
        }),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () {
            setState(() =>
                _speakers.add({'name': '', 'role': '', 'image': null}));
            _onFormChanged();
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: _accent.withOpacity(0.25),
                  style: BorderStyle.solid),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.add, size: 14, color: _accent),
                SizedBox(width: 6),
                Text('Add Speaker',
                    style: TextStyle(
                        color: _accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _speakerRow(int i, Map<String, dynamic> s) {
    final nameCtrl =
        TextEditingController(text: s['name'] as String? ?? '');
    final roleCtrl =
        TextEditingController(text: s['role'] as String? ?? '');
    nameCtrl.addListener(() {
      _speakers[i]['name'] = nameCtrl.text;
      _onFormChanged();
    });
    roleCtrl.addListener(() {
      _speakers[i]['role'] = roleCtrl.text;
      _onFormChanged();
    });

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              (s['name'] as String? ?? '').isNotEmpty
                  ? (s['name'] as String)[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  color: _accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 14),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: _ink, fontSize: 13),
                  decoration: _miniDecoration('Name'),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: roleCtrl,
                  style: const TextStyle(color: _ink, fontSize: 13),
                  decoration: _miniDecoration('Role / Title'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() => _speakers.removeAt(i));
              _onFormChanged();
            },
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.remove_circle_outline,
                  size: 18, color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sponsors section ──────────────────────────────────────

  Widget _buildSponsorsSection() {
    return Column(
      children: [
        _sectionHeader(
          'Sponsors',
          Icons.handshake_outlined,
          expanded: _sponsorExpanded,
          onToggle: () =>
              setState(() => _sponsorExpanded = !_sponsorExpanded),
        ),
        AnimatedCrossFade(
          firstChild: _sponsorBody(),
          secondChild: const SizedBox.shrink(),
          crossFadeState: _sponsorExpanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _sponsorBody() {
    return Column(
      children: [
        ..._sponsors.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          return _sponsorRow(i, s);
        }),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () {
            setState(() =>
                _sponsors.add({'name': '', 'tier': 'Gold', 'logo': null}));
            _onFormChanged();
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _accent.withOpacity(0.25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.add, size: 14, color: _accent),
                SizedBox(width: 6),
                Text('Add Sponsor',
                    style: TextStyle(
                        color: _accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sponsorRow(int i, Map<String, dynamic> s) {
    final nameCtrl =
        TextEditingController(text: s['name'] as String? ?? '');
    nameCtrl.addListener(() {
      _sponsors[i]['name'] = nameCtrl.text;
      _onFormChanged();
    });
    String tier = s['tier'] as String? ?? 'Gold';

    return StatefulBuilder(builder: (ctx, setSt) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            // Tier colour dot
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _tierColorLocal(tier),
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: TextField(
                controller: nameCtrl,
                style: const TextStyle(color: _ink, fontSize: 13),
                decoration: _miniDecoration('Sponsor name'),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: tier,
                  items: _tierOptions
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t,
                                style: const TextStyle(
                                    fontSize: 12, color: _ink)),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setSt(() => tier = v);
                    setState(() {
                      _sponsors[i]['tier'] = v;
                    });
                    _onFormChanged();
                  },
                  style: const TextStyle(color: _ink, fontSize: 12),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                setState(() => _sponsors.removeAt(i));
                _onFormChanged();
              },
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.remove_circle_outline,
                    size: 18, color: Colors.redAccent),
              ),
            ),
          ],
        ),
      );
    });
  }

  Color _tierColorLocal(String tier) {
    switch (tier.toLowerCase()) {
      case 'gold': return const Color(0xFFFFD700);
      case 'silver': return const Color(0xFFB0BEC5);
      case 'bronze': return const Color(0xFFCD7F32);
      default: return const Color(0xFF90CAF9);
    }
  }

  // ── Venue section ─────────────────────────────────────────

  Widget _buildVenueSection() {
    final error = _errors['venue'];
    return Column(
      children: [
        _sectionHeader(
          'Venue',
          Icons.meeting_room_outlined,
          expanded: _venueExpanded,
          onToggle: () =>
              setState(() => _venueExpanded = !_venueExpanded),
        ),
        if (error != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    size: 14, color: Colors.redAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(error,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
        AnimatedCrossFade(
          firstChild: _venueBody(),
          secondChild: _selectedRoomId != null
              ? _selectedVenuePill()
              : const SizedBox.shrink(),
          crossFadeState: _venueExpanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _selectedVenuePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              size: 14, color: Color(0xFF2E7D32)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_selectedVenueName,
                style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _venueBody() {
    if (_venueOptions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: const Text(
          'No venues found. Add buildings and rooms from the Venue Owner portal.',
          style: TextStyle(color: _muted, fontSize: 13, height: 1.4),
        ),
      );
    }

    return Column(
      children: [
        // Hint about date-based availability
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFFE082)),
          ),
          child: Row(
            children: const [
              Icon(Icons.info_outline, size: 13, color: Color(0xFFE65100)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Venues shown for your selected event time. Greyed items are booked.',
                  style: TextStyle(fontSize: 11, color: Color(0xFFE65100)),
                ),
              ),
            ],
          ),
        ),
        ..._venueOptions.map((v) => _venueOptionTile(v)).toList(),
      ],
    );
  }

  Widget _venueOptionTile(Map<String, dynamic> v) {
    final room = v['room'] as Map<String, dynamic>;
    final building = v['building'] as Map<String, dynamic>;
    final isBooked = v['isBooked'] as bool;
    final roomId = room['id'] as String;
    final isSelected = _selectedRoomId == roomId;
    final cap = room['capacity'] as int? ?? 0;
    final address = building['address'] as String? ?? '';
    final roomName = room['name'] as String? ?? '';
    final buildingName = building['name'] as String? ?? '';

    return GestureDetector(
      onTap: isBooked
          ? null
          : () {
              setState(() {
                _selectedRoomId = roomId;
                _selectedBuildingId = building['id'] as String?;
                _selectedVenueName = '$buildingName · $roomName';
                _errors.remove('venue');
                _venueRequired = false;
              });
              _onFormChanged();
              _fetchWeather();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isBooked
              ? const Color(0xFFF7F7F7)
              : isSelected
                  ? _accent.withOpacity(0.07)
                  : _white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? _accent
                : isBooked
                    ? const Color(0xFFE0E0E0)
                    : _border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Opacity(
          opacity: isBooked ? 0.45 : 1.0,
          child: Row(
            children: [
              // Selection indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 18,
                height: 18,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? _accent : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? _accent : _border,
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 12, color: _white)
                    : null,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(roomName,
                        style: TextStyle(
                            color: isBooked ? _muted : _ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    const SizedBox(height: 2),
                    Text('$buildingName · $address',
                        style: TextStyle(
                            color: isBooked
                                ? const Color(0xFFB0B0B0)
                                : _muted,
                            fontSize: 11),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              // Capacity pill
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: isBooked
                      ? const Color(0xFFEEEEEE)
                      : const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_outline,
                        size: 10,
                        color: isBooked ? const Color(0xFFB0B0B0) : _muted),
                    const SizedBox(width: 3),
                    Text('$cap',
                        style: TextStyle(
                            fontSize: 10,
                            color: isBooked
                                ? const Color(0xFFB0B0B0)
                                : _muted,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: isBooked
                      ? Colors.redAccent.withOpacity(0.08)
                      : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  isBooked ? 'Booked' : 'Available',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: isBooked
                        ? Colors.redAccent
                        : const Color(0xFF2E7D32),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Weather card ──────────────────────────────────────────

  Widget _buildWeatherCard() {
    if (_selectedRoomId == null) return const SizedBox.shrink();

    // Risk warning banner (prominent, non-blocking)
    final warning = _weather?.showRiskWarning == true
        ? Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFF8F00), width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFE65100), size: 17),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _weather!.riskWarningText,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFBF360C),
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          )
        : const SizedBox.shrink();

    // Main card
    Widget cardBody;

    if (_weatherLoading) {
      cardBody = const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Fetching weather forecast…',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
        ),
      );
    } else if (_weather == null) {
      cardBody = Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: const [
            Icon(Icons.cloud_off_outlined,
                size: 15, color: Color(0xFF94A3B8)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Weather data unavailable. Add an OpenWeather API key in weather_service.dart for live forecasts.',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ),
          ],
        ),
      );
    } else {
      final w = _weather!;
      final condColor = w.isStorm
          ? const Color(0xFF5C35CC)
          : w.isHighRainRisk
              ? const Color(0xFF1565C0)
              : w.condition == WeatherCondition.rain
                  ? const Color(0xFF1976D2)
                  : w.condition == WeatherCondition.clear
                      ? const Color(0xFFE65100)
                      : const Color(0xFF455A64);

      cardBody = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: emoji + temp + condition + city
          Row(
            children: [
              Text(w.conditionEmoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${w.tempC.toStringAsFixed(1)}°C  ·  ${w.conditionLabel}',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: condColor),
                  ),
                  Text(
                    '${w.description}  ·  ${w.city}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF78909C)),
                  ),
                ],
              ),
              const Spacer(),
              // Precipitation chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: w.isHighRainRisk
                      ? const Color(0xFFE3F2FD)
                      : const Color(0xFFF1F8E9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: w.isHighRainRisk
                        ? const Color(0xFF90CAF9)
                        : const Color(0xFFAED581),
                  ),
                ),
                child: Text(
                  '💧 ${w.precipPct}%',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: w.isHighRainRisk
                          ? const Color(0xFF1565C0)
                          : const Color(0xFF33691E)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Row 2: indoor/outdoor recommendation
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: w.isHighRainRisk || w.isStorm
                  ? const Color(0xFFE8EAF6)
                  : const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  w.isHighRainRisk || w.isStorm
                      ? Icons.home_outlined
                      : Icons.wb_sunny_outlined,
                  size: 14,
                  color: w.isHighRainRisk || w.isStorm
                      ? const Color(0xFF3949AB)
                      : const Color(0xFF2E7D32),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    w.venueRecommendation,
                    style: TextStyle(
                        fontSize: 12,
                        color: w.isHighRainRisk || w.isStorm
                            ? const Color(0xFF283593)
                            : const Color(0xFF1B5E20),
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Row 3: AI-style insight
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.auto_awesome_outlined,
                  size: 13, color: Color(0xFF7986CB)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  w.aiInsight,
                  style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF5C6BC0)),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        warning,
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDDE1F7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.cloud_outlined,
                      size: 14, color: Color(0xFF4F46E5)),
                  SizedBox(width: 6),
                  Text(
                    'Weather Forecast',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4F46E5)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              cardBody,
            ],
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  // ── Banner preview section ────────────────────────────────

  Widget _buildBannerSection() {
    return Column(
      children: [
        _sectionHeader(
          'Event Banner',
          Icons.image_outlined,
          expanded: _bannerExpanded,
          onToggle: () =>
              setState(() => _bannerExpanded = !_bannerExpanded),
        ),
        AnimatedCrossFade(
          firstChild: _bannerBody(),
          secondChild: const SizedBox.shrink(),
          crossFadeState: _bannerExpanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _bannerBody() {
    return Column(
      children: [
        EventBannerWidget(
          title: _titleCtrl.text.isEmpty
              ? 'Your Event Title'
              : _titleCtrl.text,
          date: _start,
          venueName: _selectedVenueName,
          speakers: _speakers,
          sponsors: _sponsors,
          themeIndex: _bannerTheme,
          height: 200,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Spacer(),
            // Theme dots
            ...List.generate(themeCount, (i) {
              return GestureDetector(
                onTap: () => setState(() => _bannerTheme = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: i == _bannerTheme ? 18 : 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: i == _bannerTheme
                        ? _accent
                        : _border,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              );
            }),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () =>
                  setState(() => _bannerTheme = (_bannerTheme + 1) % themeCount),
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('Regenerate'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _ink,
                side: const BorderSide(color: _border),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Decoration helper ─────────────────────────────────────

  InputDecoration _miniDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _muted, fontSize: 12),
      filled: true,
      fillColor: _white,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _ink, width: 1.2),
      ),
    );
  }

  // ── Overlap banner ────────────────────────────────────────

  Widget _overlapBanner() {
    final overlaps = _auth.organizerEvents.where((e) {
      if (_isEdit && e['id'] == (widget.existing!['id'] as String?)) {
        return false;
      }
      final eStart = e['start'] as DateTime?;
      final eEnd = e['end'] as DateTime?;
      if (eStart == null || eEnd == null) return false;
      return _start.isBefore(eEnd) && eStart.isBefore(_end);
    }).toList();

    if (overlaps.isEmpty) return const SizedBox.shrink();

    final names = overlaps
        .map((e) => e['title'] as String? ?? 'Untitled')
        .take(3)
        .join(', ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFCC02)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFE65100), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Schedule Conflict Detected',
                    style: TextStyle(
                      color: Color(0xFFE65100),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Overlaps with: $names',
                    style: const TextStyle(
                      color: Color(0xFFE65100),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Conflict detection ────────────────────────────────────

  List<Map<String, dynamic>> get _overlappingEvents {
    return _auth.allEvents.where((e) {
      if (_isEdit && e['id'] == (widget.existing?['id'] as String?)) {
        return false;
      }
      final eStart = e['start'] as DateTime?;
      final eEnd = e['end'] as DateTime?;
      if (eStart == null || eEnd == null) return false;
      return _start.isBefore(eEnd) && eStart.isBefore(_end);
    }).toList();
  }

  void _checkAndShowConflictBanner() {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearMaterialBanners();
    final overlaps = _overlappingEvents;
    if (overlaps.isEmpty) return;
    final names = overlaps
        .take(2)
        .map((e) => '"${e['title'] as String? ?? 'Untitled'}"')
        .join(' and ');
    messenger.showMaterialBanner(MaterialBanner(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      backgroundColor: const Color(0xFFFFF3E0),
      leading: const Icon(Icons.warning_amber_rounded,
          color: Color(0xFFE65100), size: 20),
      content: Text(
        'Schedule conflict with $names. Adjust the date or pick another time.',
        style: const TextStyle(
            color: Color(0xFFBF360C), fontSize: 12, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => messenger.clearMaterialBanners(),
          child: const Text('Dismiss',
              style:
                  TextStyle(color: Color(0xFFBF360C), fontSize: 12)),
        ),
      ],
    ));
  }


  // ── AI Smart Scheduling helpers ───────────────────────────

  List<DateTime> _freeDateSuggestions() {
    final duration = _end.difference(_start);
    final suggestions = <DateTime>[];
    var candidate = _start.add(const Duration(days: 1));
    var checked = 0;
    while (suggestions.length < 3 && checked < 21) {
      checked++;
      final candidateEnd = candidate.add(duration);
      final hasConflict = _auth.allEvents.any((e) {
        if (_isEdit && e['id'] == (widget.existing?['id'] as String?)) {
          return false;
        }
        final eStart = e['start'] as DateTime?;
        final eEnd = e['end'] as DateTime?;
        if (eStart == null || eEnd == null) return false;
        return candidate.isBefore(eEnd) && eStart.isBefore(candidateEnd);
      });
      if (!hasConflict) suggestions.add(candidate);
      candidate = candidate.add(const Duration(days: 1));
    }
    return suggestions;
  }

  List<Map<String, dynamic>> _topVenueRecommendations() {
    final attendees = int.tryParse(_attendeesCtrl.text) ?? 50;
    final category = _categoryCtrl.text.toLowerCase();
    final results = _venueOptions
        .where((o) => !(o['isBooked'] as bool))
        .map((o) {
          final room = o['room'] as Map<String, dynamic>;
          final building = o['building'] as Map<String, dynamic>;
          final cap = room['capacity'] as int? ?? 0;
          final type = (room['type'] as String? ?? '').toLowerCase();
          int score = 40;
          if (cap >= attendees && cap <= attendees * 2) {
            score += 35;
          } else if (cap >= attendees) {
            score += 15;
          }
          if ((category.contains('tech') || category.contains('digital')) &&
              (type == 'conference' || type == 'boardroom')) score += 15;
          if ((category.contains('art') || category.contains('music') ||
                  category.contains('creative')) &&
              (type == 'studio' || type == 'hall')) score += 15;
          if (category.contains('outdoor') && type == 'outdoor') score += 15;
          if (category.contains('class') || category.contains('education')) {
            if (type == 'classroom') score += 15;
          }
          final occ = cap > 0
              ? (attendees / cap * 100).clamp(0.0, 100.0)
              : 0.0;
          final String reason;
          if (cap < attendees) {
            reason = 'Capacity ($cap) below expected — consider a larger space';
          } else if (score >= 75) {
            reason =
                'Excellent fit: $cap capacity for $attendees guests';
          } else {
            reason =
                'Good availability · ${occ.toStringAsFixed(0)}% forecast occupancy';
          }
          return {
            'room': room,
            'building': building,
            'score': score.clamp(0, 99),
            'occupancyForecast': occ,
            'reason': reason,
          };
        })
        .toList();
    results.sort(
        (a, b) => (b['score'] as int).compareTo(a['score'] as int));
    return results;
  }


  double get _predictedAttendance {
    final expected = int.tryParse(_attendeesCtrl.text) ?? 50;
    const dowFactors = [0.70, 0.74, 0.78, 0.81, 0.89, 0.83, 0.66];
    final dowFactor = dowFactors[_start.weekday - 1];
    final hour = _start.hour;
    final timeFactor = (hour >= 17 && hour <= 20)
        ? 1.12
        : (hour >= 10 && hour <= 14 ? 0.95 : 0.85);
    return (expected * dowFactor * timeFactor)
        .clamp(0, expected.toDouble());
  }

  double get _confidenceScore {
    final evCount = _auth.allEvents.length;
    if (evCount >= 8) return 0.87;
    if (evCount >= 4) return 0.70;
    if (evCount >= 1) return 0.55;
    return 0.40;
  }

  // ── Smart Scheduling Panel ────────────────────────────────

  Widget _buildSmartSuggestionsPanel() {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const dowFactors = [0.70, 0.74, 0.78, 0.81, 0.89, 0.83, 0.66];
    const dowMessages = [
      'Mondays typically see lower turnout.',
      'Tuesday events perform moderately.',
      'Wednesdays show good mid-week attendance.',
      'Thursdays see strong attendance.',
      'Fridays have the highest attendance rates.',
      'Saturdays drive strong engagement.',
      'Sundays typically see lower turnout.',
    ];

    final freeDates = _freeDateSuggestions();
    final venues = _topVenueRecommendations().take(3).toList();
    final predicted = _predictedAttendance;
    final confidence = _confidenceScore;
    final expected = int.tryParse(_attendeesCtrl.text) ?? 50;
    final occupancy =
        expected > 0 ? (predicted / expected * 100) : 0.0;
    final dow = _start.weekday - 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFDF5F0), Color(0xFFFAF7F2)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Color(0xFFE5C9B5)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding:
              const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_awesome,
                size: 15, color: _accent),
          ),
          title: const Text(
            'Smart Scheduling',
            style: TextStyle(
                color: _ink,
                fontSize: 13,
                fontWeight: FontWeight.w700),
          ),
          subtitle: const Text(
            'AI-powered date, venue & attendance predictions',
            style: TextStyle(color: _muted, fontSize: 11),
          ),
          children: [
            // ── A. Free Date Suggestions
            if (freeDates.isNotEmpty) ...[
              _sLabel(Icons.calendar_today_outlined,
                  'Conflict-Free Alternatives'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: freeDates.map((d) {
                  final hour = _start.hour;
                  final ampm = hour < 12 ? 'AM' : 'PM';
                  final h = hour % 12 == 0 ? 12 : hour % 12;
                  return GestureDetector(
                    onTap: () {
                      final dur = _end.difference(_start);
                      setState(() {
                        _start = DateTime(d.year, d.month, d.day,
                            _start.hour, _start.minute);
                        _end = _start.add(dur);
                      });
                      _loadVenueOptions();
                      _onFormChanged();
                      _checkAndShowConflictBanner();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: _white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _accent.withOpacity(0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]}',
                            style: const TextStyle(
                                color: _accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w700),
                          ),
                          Text('$h$ampm · no conflicts',
                              style: const TextStyle(
                                  color: _muted, fontSize: 10)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
            ],

            // ── B. Venue Recommendations
            if (venues.isNotEmpty) ...[
              _sLabel(Icons.meeting_room_outlined,
                  'Venue Recommendations'),
              const SizedBox(height: 8),
              ...venues.map((rec) {
                final room = rec['room'] as Map<String, dynamic>;
                final building =
                    rec['building'] as Map<String, dynamic>;
                final score = rec['score'] as int;
                final occ = rec['occupancyForecast'] as double;
                final reason = rec['reason'] as String;
                final roomId = room['id'] as String?;
                final isSelected = _selectedRoomId == roomId;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedRoomId = roomId;
                      _selectedBuildingId =
                          building['id'] as String?;
                      _selectedVenueName =
                          '${building['name']} · ${room['name']}';
                      _errors.remove('venue');
                    });
                    _onFormChanged();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _accent.withOpacity(0.06)
                          : _white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color:
                              isSelected ? _accent : _border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${building['name']} · ${room['name']}',
                                style: TextStyle(
                                    color: isSelected
                                        ? _accent
                                        : _ink,
                                    fontSize: 12,
                                    fontWeight:
                                        FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(reason,
                                  style: const TextStyle(
                                      color: _muted,
                                      fontSize: 10,
                                      height: 1.3)),
                              const SizedBox(height: 5),
                              Wrap(spacing: 5, children: [
                                _sChip(
                                    '${occ.toStringAsFixed(0)}% occ.',
                                    occ > 90
                                        ? Colors.redAccent
                                        : occ > 70
                                            ? const Color(
                                                0xFFD97706)
                                            : const Color(
                                                0xFF2E7D32)),
                                _sChip(
                                    '${room['capacity']} cap',
                                    _muted),
                              ]),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Text('$score',
                                style: TextStyle(
                                    color: score >= 75
                                        ? const Color(
                                            0xFF2E7D32)
                                        : _accent,
                                    fontSize: 20,
                                    fontWeight:
                                        FontWeight.w800)),
                            const Text('% match',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: _muted,
                                    fontSize: 9)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 6),
            ],

            // ── C. Prediction Metrics
            _sLabel(Icons.analytics_outlined,
                'Attendance Prediction'),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: _predTile(
                  label: 'Predicted',
                  value: '${predicted.round()}',
                  sub: 'attendees',
                  color: const Color(0xFF1565C0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _predTile(
                  label: 'Occupancy',
                  value: '${occupancy.toStringAsFixed(0)}%',
                  sub: 'of capacity',
                  color: occupancy > 90
                      ? Colors.redAccent
                      : occupancy > 70
                          ? const Color(0xFFD97706)
                          : const Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _predTile(
                  label: 'Confidence',
                  value: '${(confidence * 100).toStringAsFixed(0)}%',
                  sub: 'from history',
                  color: _accent,
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.lightbulb_outline,
                    size: 13, color: Color(0xFF1565C0)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${dowMessages[dow]} '
                    '${days[dow]} events historically fill '
                    '${(dowFactors[dow] * 100).toStringAsFixed(0)}% of expected capacity.',
                    style: const TextStyle(
                        color: Color(0xFF1565C0),
                        fontSize: 11,
                        height: 1.4),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sLabel(IconData icon, String label) {
    return Row(children: [
      Icon(icon, size: 13, color: _muted),
      const SizedBox(width: 6),
      Text(label,
          style: const TextStyle(
              color: _muted,
              fontSize: 11,
              fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _sChip(String label, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w700)),
    );
  }

  Widget _predTile({
    required String label,
    required String value,
    required String sub,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: _muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          Text(sub,
              style: const TextStyle(color: _muted, fontSize: 9)),
        ],
      ),
    );
  }

  // ── Divider ───────────────────────────────────────────────

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Divider(color: _border, height: 1),
      );

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEdit ? 'Edit Event' : 'Create Event',
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (_autosaveLabel.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.cloud_done_outlined,
                                size: 11, color: Color(0xFF2E7D32)),
                            const SizedBox(width: 4),
                            Text(
                              _autosaveLabel,
                              style: const TextStyle(
                                  color: Color(0xFF2E7D32), fontSize: 11),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: _muted),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Overlap conflict banner — always above form content
            _overlapBanner(),

            // ── Banner section
            _buildBannerSection(),
            _divider(),

            // ── Basic info
            _sectionHeader('Basic Info', Icons.edit_note_outlined),
            _field(_titleCtrl, 'Event title *', errorKey: 'title'),
            const SizedBox(height: 10),
            _field(
              _descCtrl,
              'Description — tell attendees what to expect',
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            _field(_categoryCtrl,
                'Category  (e.g. Technology, Arts & Culture)'),
            const SizedBox(height: 10),
            _field(
              _attendeesCtrl,
              'Expected number of attendees *',
              keyboardType: TextInputType.number,
              errorKey: 'attendees',
            ),
            _divider(),

            // ── Dates
            _sectionHeader('Date & Time', Icons.schedule_outlined),
            _dtTile(
              label: 'Start',
              dt: _start,
              onPicked: (d) {
                setState(() => _start = d);
                _loadVenueOptions();
                _onFormChanged();
                _checkAndShowConflictBanner();
                _fetchWeather();
              },
            ),
            const SizedBox(height: 8),
            _dtTile(
              label: 'End',
              dt: _end,
              onPicked: (d) {
                setState(() => _end = d);
                _loadVenueOptions();
                _onFormChanged();
                _checkAndShowConflictBanner();
              },
              firstDate: _start,
              errorKey: 'end',
            ),

            // Existing booking warning
            if (_isEdit &&
                (widget.existing!['bookingId'] as String?) != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFE082)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 14, color: Color(0xFFE65100)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This event has an active venue booking. Changing dates does not auto-update the booking.',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFFE65100)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            _divider(),

            // ── Weather Forecast Card
            _buildWeatherCard(),

            // ── AI Smart Scheduling Suggestions
            _buildSmartSuggestionsPanel(),
            const SizedBox(height: 4),

            // ── Venue
            _buildVenueSection(),
            _divider(),

            // ── Speakers
            _buildSpeakersSection(),
            _divider(),

            // ── Sponsors
            _buildSponsorsSection(),

            const SizedBox(height: 20),

            // ── Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _submit(status: 'draft'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ink,
                      side: const BorderSide(color: _border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Save as Draft',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _submit(status: 'published'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      _isEdit ? 'Save Changes' : 'Publish',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
