import 'package:flutter/material.dart';

// ── Theme ─────────────────────────────────────────────────────────────────────

const _bg = Color(0xFFFAF7F2);
const _white = Color(0xFFFFFFFF);
const _border = Color(0xFFE9E1D6);
const _ink = Color(0xFF1F1A17);
const _muted = Color(0xFF6E6258);
const _accent = Color(0xFFC46A3D);

// ── Enums ─────────────────────────────────────────────────────────────────────

enum StaffRole { eventManager, photographer, decorator, security, volunteer }

enum AttendanceStatus { onDuty, available, absent }

extension StaffRoleExt on StaffRole {
  String get label {
    switch (this) {
      case StaffRole.eventManager: return 'Event Manager';
      case StaffRole.photographer: return 'Photographer';
      case StaffRole.decorator:    return 'Decorator';
      case StaffRole.security:     return 'Security';
      case StaffRole.volunteer:    return 'Volunteer';
    }
  }
  IconData get icon {
    switch (this) {
      case StaffRole.eventManager: return Icons.manage_accounts_outlined;
      case StaffRole.photographer: return Icons.camera_alt_outlined;
      case StaffRole.decorator:    return Icons.auto_awesome_outlined;
      case StaffRole.security:     return Icons.security_outlined;
      case StaffRole.volunteer:    return Icons.volunteer_activism_outlined;
    }
  }
  Color get color {
    switch (this) {
      case StaffRole.eventManager: return const Color(0xFF1565C0);
      case StaffRole.photographer: return const Color(0xFF6A1B9A);
      case StaffRole.decorator:    return const Color(0xFFAD1457);
      case StaffRole.security:     return const Color(0xFF2E7D32);
      case StaffRole.volunteer:    return const Color(0xFFC46A3D);
    }
  }
}

extension AttendanceStatusExt on AttendanceStatus {
  String get label {
    switch (this) {
      case AttendanceStatus.onDuty:    return 'On Duty';
      case AttendanceStatus.available: return 'Available';
      case AttendanceStatus.absent:    return 'Absent';
    }
  }
  Color get color {
    switch (this) {
      case AttendanceStatus.onDuty:    return const Color(0xFF2E7D32);
      case AttendanceStatus.available: return const Color(0xFF1565C0);
      case AttendanceStatus.absent:    return Colors.redAccent;
    }
  }
  Color get bgColor {
    switch (this) {
      case AttendanceStatus.onDuty:    return const Color(0xFFE8F5E9);
      case AttendanceStatus.available: return const Color(0xFFE3F2FD);
      case AttendanceStatus.absent:    return const Color(0xFFFFEBEE);
    }
  }
}

// ── Models ────────────────────────────────────────────────────────────────────

class StaffShift {
  final int startH, startM, endH, endM;
  const StaffShift(this.startH, this.startM, this.endH, this.endM);

  String get label =>
      '${_t(startH, startM)} – ${_t(endH, endM)}';

  static String _t(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  bool overlapsWith(StaffShift other) =>
      _mins(startH, startM) < _mins(other.endH, other.endM) &&
      _mins(other.startH, other.startM) < _mins(endH, endM);

  static int _mins(int h, int m) => h * 60 + m;

  bool get isActive {
    final now = DateTime.now();
    final cur = _mins(now.hour, now.minute);
    return cur >= _mins(startH, startM) && cur < _mins(endH, endM);
  }
}

class StaffTask {
  final String id;
  String title;
  DateTime deadline;
  bool completed;
  StaffTask({required this.id, required this.title, required this.deadline, this.completed = false});
}

class ActivityEntry {
  final String staffId;
  final String staffName;
  final String message;
  final DateTime time;
  final IconData icon;
  final Color color;
  ActivityEntry({
    required this.staffId,
    required this.staffName,
    required this.message,
    required this.time,
    required this.icon,
    required this.color,
  });
}

class StaffMember {
  final String id;
  final String name;
  final StaffRole role;
  List<String> assignedEvents;
  final StaffShift shift;
  AttendanceStatus status;
  DateTime? checkedInAt;
  DateTime? checkedOutAt;
  final List<StaffTask> tasks;

  StaffMember({
    required this.id,
    required this.name,
    required this.role,
    required this.assignedEvents,
    required this.shift,
    required this.status,
    this.checkedInAt,
    this.checkedOutAt,
    List<StaffTask>? tasks,
  }) : tasks = tasks ?? [];

  bool get isLate {
    if (checkedInAt == null) return false;
    final shiftStartMins = shift.startH * 60 + shift.startM;
    final checkInMins = checkedInAt!.hour * 60 + checkedInAt!.minute;
    return checkInMins > shiftStartMins + 15;
  }

  double get taskProgress {
    if (tasks.isEmpty) return 0;
    return tasks.where((t) => t.completed).length / tasks.length;
  }

  int get pendingTasks => tasks.where((t) => !t.completed).length;
}

// ── Seed data ─────────────────────────────────────────────────────────────────

const _allEvents = [
  'Tech Summit London',
  'Creative Arts Gala',
  'Music Festival Bristol',
];

List<StaffMember> _buildSeed() {
  final now = DateTime.now();
  return [
    StaffMember(
      id: 's1', name: 'Rachel Thornton', role: StaffRole.eventManager,
      assignedEvents: ['Tech Summit London'],
      shift: const StaffShift(8, 0, 18, 0),
      status: AttendanceStatus.onDuty,
      checkedInAt: now.subtract(const Duration(hours: 2)),
      tasks: [
        StaffTask(id: 't1', title: 'Confirm AV setup', deadline: now.add(const Duration(hours: 2)), completed: true),
        StaffTask(id: 't2', title: 'Brief volunteers', deadline: now.add(const Duration(hours: 1))),
        StaffTask(id: 't3', title: 'Coordinate keynote speaker', deadline: now.add(const Duration(hours: 3))),
      ],
    ),
    StaffMember(
      id: 's2', name: 'Marcus Webb', role: StaffRole.photographer,
      assignedEvents: ['Tech Summit London', 'Creative Arts Gala'],
      shift: const StaffShift(9, 0, 17, 0),
      status: AttendanceStatus.onDuty,
      checkedInAt: now.subtract(const Duration(hours: 1, minutes: 5)),
      tasks: [
        StaffTask(id: 't4', title: 'Shoot opening ceremony', deadline: now.add(const Duration(hours: 1)), completed: true),
        StaffTask(id: 't5', title: 'Edit highlight reel', deadline: now.add(const Duration(days: 1))),
      ],
    ),
    StaffMember(
      id: 's3', name: 'Aisha Patel', role: StaffRole.decorator,
      assignedEvents: ['Creative Arts Gala'],
      shift: const StaffShift(7, 0, 13, 0),
      status: AttendanceStatus.available,
      checkedInAt: now.subtract(const Duration(hours: 4)),
      checkedOutAt: now.subtract(const Duration(minutes: 30)),
      tasks: [
        StaffTask(id: 't6', title: 'Set up floral arrangements', deadline: now.subtract(const Duration(hours: 2)), completed: true),
        StaffTask(id: 't7', title: 'Stage dressing', deadline: now.subtract(const Duration(hours: 1)), completed: true),
      ],
    ),
    StaffMember(
      id: 's4', name: 'Connor Hughes', role: StaffRole.security,
      assignedEvents: ['Music Festival Bristol'],
      shift: const StaffShift(12, 0, 22, 0),
      status: AttendanceStatus.onDuty,
      checkedInAt: now.subtract(const Duration(minutes: 45)),
      tasks: [
        StaffTask(id: 't8', title: 'Gate perimeter check', deadline: now.add(const Duration(hours: 1))),
        StaffTask(id: 't9', title: 'Crowd capacity report', deadline: now.add(const Duration(hours: 4))),
      ],
    ),
    StaffMember(
      id: 's5', name: 'Priya Mehta', role: StaffRole.volunteer,
      assignedEvents: ['Tech Summit London'],
      shift: const StaffShift(10, 0, 16, 0),
      status: AttendanceStatus.absent,
      tasks: [
        StaffTask(id: 't10', title: 'Registration desk', deadline: now.add(const Duration(hours: 2))),
        StaffTask(id: 't11', title: 'Hand out lanyards', deadline: now.add(const Duration(hours: 1))),
      ],
    ),
    StaffMember(
      id: 's6', name: 'James Holloway', role: StaffRole.eventManager,
      assignedEvents: ['Music Festival Bristol'],
      shift: const StaffShift(8, 0, 20, 0),
      status: AttendanceStatus.onDuty,
      checkedInAt: now.subtract(const Duration(hours: 3)),
      tasks: [
        StaffTask(id: 't12', title: 'Liaise with stage crew', deadline: now.add(const Duration(minutes: 30)), completed: true),
        StaffTask(id: 't13', title: 'Artist meet & greet schedule', deadline: now.add(const Duration(hours: 2))),
        StaffTask(id: 't14', title: 'End-of-night debrief', deadline: now.add(const Duration(hours: 8))),
      ],
    ),
    StaffMember(
      id: 's7', name: 'Lena Fischer', role: StaffRole.photographer,
      assignedEvents: ['Creative Arts Gala'],
      shift: const StaffShift(14, 0, 21, 0),
      status: AttendanceStatus.available,
      tasks: [
        StaffTask(id: 't15', title: 'Portrait session', deadline: now.add(const Duration(hours: 3))),
      ],
    ),
    StaffMember(
      id: 's8', name: 'Tom Bradley', role: StaffRole.security,
      assignedEvents: ['Tech Summit London'],
      shift: const StaffShift(7, 0, 19, 0),
      status: AttendanceStatus.absent,
      tasks: [
        StaffTask(id: 't16', title: 'VIP entrance patrol', deadline: now.add(const Duration(hours: 2))),
      ],
    ),
    StaffMember(
      id: 's9', name: 'Nia Owens', role: StaffRole.volunteer,
      assignedEvents: ['Creative Arts Gala'],
      shift: const StaffShift(13, 0, 19, 0),
      status: AttendanceStatus.available,
      checkedInAt: now.subtract(const Duration(minutes: 20, hours: 1)),
      checkedOutAt: now.subtract(const Duration(minutes: 5)),
      tasks: [
        StaffTask(id: 't17', title: 'Guest welcome desk', deadline: now.add(const Duration(hours: 1)), completed: true),
      ],
    ),
    StaffMember(
      id: 's10', name: 'Ravi Sharma', role: StaffRole.decorator,
      assignedEvents: ['Music Festival Bristol'],
      shift: const StaffShift(9, 0, 15, 0),
      status: AttendanceStatus.onDuty,
      checkedInAt: now.subtract(const Duration(hours: 1, minutes: 30)),
      tasks: [
        StaffTask(id: 't18', title: 'Stage banner install', deadline: now.add(const Duration(minutes: 45)), completed: true),
        StaffTask(id: 't19', title: 'Lighting rig decoration', deadline: now.add(const Duration(hours: 2))),
      ],
    ),
  ];
}

// ── Tab ───────────────────────────────────────────────────────────────────────

class OrganizerTeamTab extends StatefulWidget {
  const OrganizerTeamTab({super.key});

  @override
  State<OrganizerTeamTab> createState() => _OrganizerTeamTabState();
}

class _OrganizerTeamTabState extends State<OrganizerTeamTab>
    with SingleTickerProviderStateMixin {
  late final TabController _innerTab;
  final _searchCtrl = TextEditingController();
  StaffRole? _filterRole;
  String? _filterEvent;
  AttendanceStatus? _filterStatus;
  String _searchQuery = '';

  final List<StaffMember> _staff = _buildSeed();
  final List<ActivityEntry> _feed = [];

  @override
  void initState() {
    super.initState();
    _innerTab = TabController(length: 2, vsync: this);
    _seedFeed();
  }

  void _seedFeed() {
    final now = DateTime.now();
    _feed.addAll([
      ActivityEntry(staffId: 's1', staffName: 'Rachel Thornton', message: 'Checked in for Tech Summit London', time: now.subtract(const Duration(hours: 2)), icon: Icons.login_rounded, color: const Color(0xFF2E7D32)),
      ActivityEntry(staffId: 's2', staffName: 'Marcus Webb', message: 'Completed task: Shoot opening ceremony', time: now.subtract(const Duration(hours: 1, minutes: 30)), icon: Icons.check_circle_outline, color: _accent),
      ActivityEntry(staffId: 's6', staffName: 'James Holloway', message: 'Checked in for Music Festival Bristol', time: now.subtract(const Duration(hours: 3)), icon: Icons.login_rounded, color: const Color(0xFF2E7D32)),
      ActivityEntry(staffId: 's3', staffName: 'Aisha Patel', message: 'Checked out — shift complete', time: now.subtract(const Duration(minutes: 30)), icon: Icons.logout_rounded, color: _muted),
      ActivityEntry(staffId: 's10', staffName: 'Ravi Sharma', message: 'Completed task: Stage banner install', time: now.subtract(const Duration(hours: 1)), icon: Icons.check_circle_outline, color: _accent),
      ActivityEntry(staffId: 's6', staffName: 'James Holloway', message: 'Completed task: Liaise with stage crew', time: now.subtract(const Duration(minutes: 45)), icon: Icons.check_circle_outline, color: _accent),
    ]);
    _feed.sort((a, b) => b.time.compareTo(a.time));
  }

  @override
  void dispose() {
    _innerTab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<String> get _eventNames =>
      _staff.expand((s) => s.assignedEvents).toSet().toList()..sort();

  List<StaffMember> get _filtered => _staff.where((s) {
    final q = _searchQuery.toLowerCase();
    final matchSearch = q.isEmpty ||
        s.name.toLowerCase().contains(q) ||
        s.assignedEvents.any((e) => e.toLowerCase().contains(q)) ||
        s.role.label.toLowerCase().contains(q);
    final matchRole = _filterRole == null || s.role == _filterRole;
    final matchEvent = _filterEvent == null || s.assignedEvents.contains(_filterEvent);
    final matchStatus = _filterStatus == null || s.status == _filterStatus;
    return matchSearch && matchRole && matchEvent && matchStatus;
  }).toList();

  int get _totalStaff => _staff.length;
  int get _onDuty => _staff.where((s) => s.status == AttendanceStatus.onDuty).length;
  int get _absent => _staff.where((s) => s.status == AttendanceStatus.absent).length;
  int get _available => _staff.where((s) => s.status == AttendanceStatus.available).length;

  // Detect shift overlaps for a staff member
  bool _hasConflict(StaffMember m) {
    for (final other in _staff) {
      if (other.id == m.id) continue;
      final shared = m.assignedEvents.any((e) => other.assignedEvents.contains(e));
      if (shared && m.shift.overlapsWith(other.shift)) return true;
    }
    return false;
  }

  void _addFeedEntry(ActivityEntry entry) {
    setState(() {
      _feed.insert(0, entry);
    });
  }

  void _checkIn(StaffMember m) {
    setState(() {
      m.checkedInAt = DateTime.now();
      m.status = AttendanceStatus.onDuty;
    });
    _addFeedEntry(ActivityEntry(
      staffId: m.id, staffName: m.name,
      message: 'Checked in${m.assignedEvents.isNotEmpty ? ' for ${m.assignedEvents.first}' : ''}${m.isLate ? ' — LATE' : ''}',
      time: DateTime.now(),
      icon: m.isLate ? Icons.warning_amber_rounded : Icons.login_rounded,
      color: m.isLate ? const Color(0xFFD97706) : const Color(0xFF2E7D32),
    ));
  }

  void _checkOut(StaffMember m) {
    setState(() {
      m.checkedOutAt = DateTime.now();
      m.status = AttendanceStatus.available;
    });
    _addFeedEntry(ActivityEntry(
      staffId: m.id, staffName: m.name,
      message: 'Checked out — shift complete',
      time: DateTime.now(),
      icon: Icons.logout_rounded,
      color: _muted,
    ));
  }

  void _completeTask(StaffMember m, StaffTask task) {
    setState(() => task.completed = true);
    _addFeedEntry(ActivityEntry(
      staffId: m.id, staffName: m.name,
      message: 'Completed task: ${task.title}',
      time: DateTime.now(),
      icon: Icons.check_circle_outline,
      color: _accent,
    ));
  }

  void _showDetailSheet(StaffMember m) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _StaffDetailSheet(
        member: m,
        allEvents: _allEvents,
        hasConflict: _hasConflict(m),
        onCheckIn: () { _checkIn(m); Navigator.pop(context); },
        onCheckOut: () { _checkOut(m); Navigator.pop(context); },
        onCompleteTask: (task) => _completeTask(m, task),
        onAddTask: (task) => setState(() => m.tasks.add(task)),
        onReassign: (events) {
          setState(() => m.assignedEvents = events);
          _addFeedEntry(ActivityEntry(
            staffId: m.id, staffName: m.name,
            message: 'Reassigned to: ${events.join(', ')}',
            time: DateTime.now(),
            icon: Icons.swap_horiz_rounded,
            color: const Color(0xFF1565C0),
          ));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildMetrics(),
        Container(
          color: _white,
          child: TabBar(
            controller: _innerTab,
            labelColor: _ink,
            unselectedLabelColor: _muted,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
            indicator: const UnderlineTabIndicator(
                borderSide: BorderSide(color: _accent, width: 2.5)),
            indicatorSize: TabBarIndicatorSize.label,
            tabs: const [
              Tab(text: 'Staff'),
              Tab(text: 'Activity Feed'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _innerTab,
            children: [
              _buildStaffView(),
              _buildFeedView(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStaffView() {
    final filtered = _filtered;
    return Column(
      children: [
        _buildSearchBar(),
        _buildFilters(),
        Expanded(
          child: filtered.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _StaffCard(
                    member: filtered[i],
                    hasConflict: _hasConflict(filtered[i]),
                    onTap: () => _showDetailSheet(filtered[i]),
                    onCheckIn: () => _checkIn(filtered[i]),
                    onCheckOut: () => _checkOut(filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFeedView() {
    if (_feed.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: _border.withOpacity(0.3), shape: BoxShape.circle),
              child: const Icon(Icons.history_outlined, size: 36, color: _muted),
            ),
            const SizedBox(height: 14),
            const Text('No activity yet', style: TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      itemCount: _feed.length,
      itemBuilder: (_, i) => _FeedItem(entry: _feed[i]),
    );
  }

  Widget _buildMetrics() {
    return Container(
      color: _white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          _metricTile('Total Staff', '$_totalStaff', Icons.groups_outlined, _ink),
          const SizedBox(width: 8),
          _metricTile('On Duty', '$_onDuty', Icons.badge_outlined, const Color(0xFF2E7D32)),
          const SizedBox(width: 8),
          _metricTile('Absent', '$_absent', Icons.person_off_outlined, Colors.redAccent),
          const SizedBox(width: 8),
          _metricTile('Available', '$_available', Icons.person_outline, const Color(0xFF1565C0)),
        ],
      ),
    );
  }

  Widget _metricTile(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: _white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(color: _ink, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search staff by name, role or event…',
          hintStyle: const TextStyle(color: _muted, fontSize: 13),
          prefixIcon: const Icon(Icons.search, size: 18, color: _muted),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 16, color: _muted),
                  onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); },
                )
              : null,
          filled: true, fillColor: _bg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _accent, width: 1.5)),
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: _white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _Chip(label: 'All Roles', selected: _filterRole == null, onTap: () => setState(() => _filterRole = null)),
            const SizedBox(width: 6),
            ...StaffRole.values.map((r) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _Chip(label: r.label, selected: _filterRole == r, color: r.color, onTap: () => setState(() => _filterRole = _filterRole == r ? null : r)),
            )),
            const SizedBox(width: 6),
            Container(width: 1, height: 20, color: _border),
            const SizedBox(width: 6),
            _Chip(label: 'All Events', selected: _filterEvent == null, onTap: () => setState(() => _filterEvent = null)),
            const SizedBox(width: 6),
            ..._eventNames.map((e) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _Chip(label: e, selected: _filterEvent == e, onTap: () => setState(() => _filterEvent = _filterEvent == e ? null : e)),
            )),
            const SizedBox(width: 6),
            Container(width: 1, height: 20, color: _border),
            const SizedBox(width: 6),
            ...AttendanceStatus.values.map((s) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _Chip(label: s.label, selected: _filterStatus == s, color: s.color, onTap: () => setState(() => _filterStatus = _filterStatus == s ? null : s)),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: _border.withOpacity(0.3), shape: BoxShape.circle),
              child: const Icon(Icons.group_off_outlined, size: 40, color: _muted),
            ),
            const SizedBox(height: 16),
            const Text('No staff found', style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Try adjusting your search or filters.', style: TextStyle(color: _muted, fontSize: 13), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Staff Card ────────────────────────────────────────────────────────────────

class _StaffCard extends StatelessWidget {
  final StaffMember member;
  final bool hasConflict;
  final VoidCallback onTap;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;

  const _StaffCard({
    required this.member,
    required this.hasConflict,
    required this.onTap,
    required this.onCheckIn,
    required this.onCheckOut,
  });

  @override
  Widget build(BuildContext context) {
    final m = member;
    final role = m.role;
    final status = m.status;
    final now = DateTime.now();
    final isActive = m.shift.isActive;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, top: 4),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: hasConflict ? const Color(0xFFFFB74D) : _border),
          boxShadow: [BoxShadow(color: _ink.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            // Conflict banner
            if (hasConflict)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded, size: 13, color: Color(0xFFE65100)),
                    SizedBox(width: 6),
                    Text('Shift overlap detected', style: TextStyle(color: Color(0xFFBF360C), fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(color: role.color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: Icon(role.icon, size: 20, color: role.color),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(m.name, style: const TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                                ),
                                const SizedBox(width: 6),
                                _statusBadge(status),
                                if (m.isLate) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(4)),
                                    child: const Text('LATE', style: TextStyle(color: Color(0xFFE65100), fontSize: 9, fontWeight: FontWeight.w800)),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: role.color.withOpacity(0.08), borderRadius: BorderRadius.circular(5)),
                              child: Text(role.label, style: TextStyle(color: role.color, fontSize: 10, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Events
                  _infoRow(Icons.event_outlined, m.assignedEvents.join(', ')),
                  const SizedBox(height: 4),

                  // Shift
                  _infoRow(
                    Icons.schedule_outlined,
                    m.shift.label + (isActive ? ' · ACTIVE' : ''),
                    valueColor: isActive ? const Color(0xFF2E7D32) : null,
                  ),
                  if (m.checkedInAt != null) ...[
                    const SizedBox(height: 4),
                    _infoRow(Icons.login_rounded, 'Checked in ${_timeAgo(m.checkedInAt!)}', valueColor: const Color(0xFF2E7D32)),
                  ],
                  if (m.checkedOutAt != null) ...[
                    const SizedBox(height: 4),
                    _infoRow(Icons.logout_rounded, 'Checked out ${_timeAgo(m.checkedOutAt!)}'),
                  ],

                  // Tasks progress
                  if (m.tasks.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: m.taskProgress,
                              minHeight: 4,
                              backgroundColor: _border,
                              valueColor: AlwaysStoppedAnimation<Color>(_accent),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${m.tasks.where((t) => t.completed).length}/${m.tasks.length} tasks',
                          style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                        if (m.pendingTasks > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(color: _accent.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                            child: Text('${m.pendingTasks} pending', style: const TextStyle(color: _accent, fontSize: 9, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                  ],

                  const SizedBox(height: 10),
                  // Check-in / out actions
                  Row(
                    children: [
                      if (m.checkedInAt == null)
                        _actionBtn('Check In', Icons.login_rounded, const Color(0xFF2E7D32), onCheckIn),
                      if (m.checkedInAt != null && m.checkedOutAt == null)
                        _actionBtn('Check Out', Icons.logout_rounded, _muted, onCheckOut),
                      const Spacer(),
                      GestureDetector(
                        onTap: onTap,
                        child: Row(
                          children: const [
                            Text('Details', style: TextStyle(color: _accent, fontSize: 12, fontWeight: FontWeight.w600)),
                            SizedBox(width: 2),
                            Icon(Icons.chevron_right_rounded, size: 16, color: _accent),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(AttendanceStatus s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: s.bgColor, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 5, height: 5, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
          const SizedBox(width: 3),
          Text(s.label, style: TextStyle(color: s.color, fontSize: 9, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 12, color: _muted),
        const SizedBox(width: 5),
        Expanded(
          child: Text(text,
              style: TextStyle(color: valueColor ?? _muted, fontSize: 11, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

// ── Staff Detail Sheet ────────────────────────────────────────────────────────

class _StaffDetailSheet extends StatefulWidget {
  final StaffMember member;
  final List<String> allEvents;
  final bool hasConflict;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;
  final void Function(StaffTask) onCompleteTask;
  final void Function(StaffTask) onAddTask;
  final void Function(List<String>) onReassign;

  const _StaffDetailSheet({
    required this.member,
    required this.allEvents,
    required this.hasConflict,
    required this.onCheckIn,
    required this.onCheckOut,
    required this.onCompleteTask,
    required this.onAddTask,
    required this.onReassign,
  });

  @override
  State<_StaffDetailSheet> createState() => _StaffDetailSheetState();
}

class _StaffDetailSheetState extends State<_StaffDetailSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  late Set<String> _selectedEvents;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _selectedEvents = Set.from(widget.member.assignedEvents);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    final role = m.role;
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
            // Handle
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 10),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: role.color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Icon(role.icon, size: 22, color: role.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.name, style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w800)),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: role.color.withOpacity(0.08), borderRadius: BorderRadius.circular(5)),
                              child: Text(role.label, style: TextStyle(color: role.color, fontSize: 10, fontWeight: FontWeight.w600)),
                            ),
                            if (m.isLate) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(4)),
                                child: const Text('LATE ARRIVAL', style: TextStyle(color: Color(0xFFE65100), fontSize: 9, fontWeight: FontWeight.w800)),
                              ),
                            ],
                            if (widget.hasConflict) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(4)),
                                child: const Text('CONFLICT', style: TextStyle(color: Color(0xFFE65100), fontSize: 9, fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: _muted)),
                ],
              ),
            ),
            // Inner tabs
            Container(
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _border))),
              child: TabBar(
                controller: _tab,
                labelColor: _ink, unselectedLabelColor: _muted,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                indicator: const UnderlineTabIndicator(borderSide: BorderSide(color: _accent, width: 2)),
                indicatorSize: TabBarIndicatorSize.label,
                tabs: const [Tab(text: 'Overview'), Tab(text: 'Tasks'), Tab(text: 'Assign')],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _buildOverview(m),
                  _buildTasks(m),
                  _buildAssign(m),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverview(StaffMember m) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Shift info
        _section('Shift Details', Icons.schedule_outlined),
        _detailRow('Shift', m.shift.label),
        _detailRow('Status', m.shift.isActive ? 'Active now' : 'Not active', valueColor: m.shift.isActive ? const Color(0xFF2E7D32) : _muted),
        if (m.checkedInAt != null)
          _detailRow('Checked In', _fmtTime(m.checkedInAt!), valueColor: m.isLate ? const Color(0xFFE65100) : const Color(0xFF2E7D32)),
        if (m.checkedOutAt != null)
          _detailRow('Checked Out', _fmtTime(m.checkedOutAt!)),
        if (widget.hasConflict)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFFE0B2))),
            child: Row(
              children: const [
                Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFE65100)),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Shift overlaps with another staff member on the same event.', style: TextStyle(color: Color(0xFFBF360C), fontSize: 12, height: 1.4)),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),

        // Actions
        _section('Attendance', Icons.badge_outlined),
        const SizedBox(height: 6),
        Row(
          children: [
            if (m.checkedInAt == null)
              Expanded(child: _sheetBtn('Check In', Icons.login_rounded, const Color(0xFF2E7D32), widget.onCheckIn)),
            if (m.checkedInAt != null && m.checkedOutAt == null) ...[
              Expanded(child: _sheetBtn('Check Out', Icons.logout_rounded, _muted, widget.onCheckOut)),
            ],
            if (m.checkedInAt != null && m.checkedOutAt != null)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
                  alignment: Alignment.center,
                  child: const Text('Shift Complete', style: TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Attendance history summary
        _section('History', Icons.history_outlined),
        _detailRow('Check-ins Today', m.checkedInAt != null ? '1' : '0'),
        _detailRow('Shifts Completed', m.checkedOutAt != null ? '1' : '0'),
        _detailRow('Tasks Done', '${m.tasks.where((t) => t.completed).length} / ${m.tasks.length}'),
      ],
    );
  }

  Widget _buildTasks(StaffMember m) {
    return Column(
      children: [
        Expanded(
          child: m.tasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.task_outlined, size: 40, color: _muted),
                      SizedBox(height: 12),
                      Text('No tasks assigned', style: TextStyle(color: _ink, fontWeight: FontWeight.w700)),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    // Progress header
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: _accent.withOpacity(0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: _accent.withOpacity(0.2))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${(m.taskProgress * 100).toStringAsFixed(0)}% complete', style: const TextStyle(color: _accent, fontSize: 13, fontWeight: FontWeight.w700)),
                              Text('${m.tasks.where((t) => t.completed).length}/${m.tasks.length}', style: const TextStyle(color: _muted, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: m.taskProgress,
                              minHeight: 6,
                              backgroundColor: _border,
                              valueColor: const AlwaysStoppedAnimation<Color>(_accent),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...m.tasks.map((task) => _TaskTile(
                      task: task,
                      onComplete: task.completed ? null : () => setState(() => widget.onCompleteTask(task)),
                    )),
                  ],
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: _border))),
          child: SafeArea(
            top: false,
            child: ElevatedButton.icon(
              onPressed: () => _showAddTaskDialog(m),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Task', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent, foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                minimumSize: const Size(double.infinity, 0),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showAddTaskDialog(StaffMember m) {
    final ctrl = TextEditingController();
    DateTime deadline = DateTime.now().add(const Duration(hours: 2));
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: _white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Task', style: TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 15)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ctrl,
                style: const TextStyle(color: _ink, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Task title',
                  labelStyle: const TextStyle(color: _muted, fontSize: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(context: ctx, initialDate: deadline, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                  if (d != null) setD(() => deadline = d);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 14, color: _muted),
                      const SizedBox(width: 8),
                      Text('Deadline: ${_fmt(deadline)}', style: const TextStyle(color: _ink, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _muted))),
            ElevatedButton(
              onPressed: () {
                if (ctrl.text.trim().isNotEmpty) {
                  final task = StaffTask(id: 'task_${DateTime.now().millisecondsSinceEpoch}', title: ctrl.text.trim(), deadline: deadline);
                  widget.onAddTask(task);
                  setState(() {});
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssign(StaffMember m) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Assign to Events', style: TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Select one or more events for this staff member.', style: TextStyle(color: _muted, fontSize: 12)),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: widget.allEvents.map((event) {
              final selected = _selectedEvents.contains(event);
              return GestureDetector(
                onTap: () => setState(() {
                  if (selected) { _selectedEvents.remove(event); } else { _selectedEvents.add(event); }
                }),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected ? _accent.withOpacity(0.06) : _white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: selected ? _accent : _border, width: selected ? 1.5 : 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event_outlined, size: 18, color: selected ? _accent : _muted),
                      const SizedBox(width: 12),
                      Expanded(child: Text(event, style: TextStyle(color: selected ? _accent : _ink, fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w500))),
                      if (selected) const Icon(Icons.check_circle_rounded, size: 18, color: _accent),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: _border))),
          child: SafeArea(
            top: false,
            child: ElevatedButton(
              onPressed: _selectedEvents.isEmpty ? null : () {
                widget.onReassign(_selectedEvents.toList());
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent, foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                minimumSize: const Size(double.infinity, 0),
                disabledBackgroundColor: _border,
              ),
              child: const Text('Save Assignment', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _section(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(width: 24, height: 24, decoration: BoxDecoration(color: _accent.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Icon(icon, size: 13, color: _accent)),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: _muted, fontSize: 12))),
          Text(value, style: TextStyle(color: valueColor ?? _ink, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _sheetBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.25))),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  static String _fmt(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  static String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

// ── Task Tile ─────────────────────────────────────────────────────────────────

class _TaskTile extends StatelessWidget {
  final StaffTask task;
  final VoidCallback? onComplete;

  const _TaskTile({required this.task, this.onComplete});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final overdue = !task.completed && task.deadline.isBefore(now);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: task.completed ? const Color(0xFFF0FFF4) : _white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: overdue ? Colors.redAccent.withOpacity(0.4) : task.completed ? const Color(0xFF2E7D32).withOpacity(0.2) : _border),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onComplete,
            child: Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: task.completed ? const Color(0xFF2E7D32) : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: task.completed ? const Color(0xFF2E7D32) : overdue ? Colors.redAccent : _border, width: 1.5),
              ),
              child: task.completed ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    color: task.completed ? _muted : _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: task.completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.schedule_outlined, size: 11, color: overdue ? Colors.redAccent : _muted),
                    const SizedBox(width: 3),
                    Text(
                      _deadlineLabel(task.deadline, now),
                      style: TextStyle(color: overdue ? Colors.redAccent : _muted, fontSize: 10, fontWeight: overdue ? FontWeight.w700 : FontWeight.w400),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!task.completed && onComplete != null)
            GestureDetector(
              onTap: onComplete,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _accent.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                child: const Text('Done', style: TextStyle(color: _accent, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }

  static String _deadlineLabel(DateTime d, DateTime now) {
    if (d.isBefore(now)) {
      final diff = now.difference(d);
      if (diff.inMinutes < 60) return 'Overdue ${diff.inMinutes}m';
      return 'Overdue ${diff.inHours}h';
    }
    final diff = d.difference(now);
    if (diff.inMinutes < 60) return 'Due in ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Due in ${diff.inHours}h';
    return 'Due ${d.day}/${d.month}';
  }
}

// ── Feed Item ─────────────────────────────────────────────────────────────────

class _FeedItem extends StatelessWidget {
  final ActivityEntry entry;
  const _FeedItem({required this.entry});

  @override
  Widget build(BuildContext context) {
    final diff = DateTime.now().difference(entry.time);
    final ago = diff.inMinutes < 1
        ? 'just now'
        : diff.inMinutes < 60
            ? '${diff.inMinutes}m ago'
            : '${diff.inHours}h ago';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: _ink.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: entry.color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(entry.icon, size: 16, color: entry.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.staffName, style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(entry.message, style: const TextStyle(color: _muted, fontSize: 12, height: 1.3)),
              ],
            ),
          ),
          Text(ago, style: const TextStyle(color: _muted, fontSize: 10)),
        ],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _Chip({required this.label, required this.selected, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? _ink;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(0.1) : _bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c : _border, width: selected ? 1.5 : 1),
        ),
        child: Text(label, style: TextStyle(color: selected ? c : _muted, fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }
}
