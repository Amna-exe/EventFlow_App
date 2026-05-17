import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../services/wishlist_service.dart';

const _kPrimary = Color(0xFFC46A3D);
const _kPrimaryLight = Color(0xFFFFF1E8);
const _kTextDark = Color(0xFF1F1A17);
const _kTextMid = Color(0xFF6E6258);
const _kTextLight = Color(0xFFA09489);
const _kBorder = Color(0xFFE9E1D6);
const _kSuccess = Color(0xFF3D7A5A);
const _kSuccessLight = Color(0xFFD1FAE5);
const _kBg = Color(0xFFFAF7F2);

const _catColors = <String, Color>{
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

Color _catColor(String c) => _catColors[c] ?? _kPrimary;

class AttendeeWishlistTab extends StatefulWidget {
  final String userId;
  final Set<String> registeredIds;
  final void Function(Map<String, dynamic>) onEventTap;
  final void Function(Map<String, dynamic>) onToggleRegistration;
  final String Function(Map<String, dynamic>) locationLabel;
  final String Function(Map<String, dynamic>) organizerName;

  const AttendeeWishlistTab({
    super.key,
    required this.userId,
    required this.registeredIds,
    required this.onEventTap,
    required this.onToggleRegistration,
    required this.locationLabel,
    required this.organizerName,
  });

  @override
  State<AttendeeWishlistTab> createState() => _AttendeeWishlistTabState();
}

class _AttendeeWishlistTabState extends State<AttendeeWishlistTab> {
  final _auth = AuthService();
  final _wish = WishlistService();

  List<Map<String, dynamic>> get _saved {
    if (widget.userId.isEmpty) return [];
    final ids = _wish.savedFor(widget.userId);
    return _auth.allEvents
        .where((e) =>
            ids.contains(e['id'] as String) && e['status'] == 'published')
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

  @override
  Widget build(BuildContext context) {
    if (widget.userId.isEmpty) return _notLoggedIn();

    final saved = _saved;

    if (saved.isEmpty) return _emptyState();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Saved Events',
                  style: TextStyle(
                      color: _kTextDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _kPrimaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${saved.length}',
                    style: const TextStyle(
                        color: _kPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Events you\'ve bookmarked to check out later',
              style: const TextStyle(color: _kTextMid, fontSize: 13)),
          const SizedBox(height: 20),
          ...saved.map((e) => _savedCard(e)),
        ],
      ),
    );
  }

  Widget _savedCard(Map<String, dynamic> e) {
    final category = (e['category'] as String? ?? '');
    final color = _catColor(category);
    final start = e['start'] as DateTime?;
    final loc = widget.locationLabel(e);
    final org = widget.organizerName(e);
    final isRegistered =
        widget.registeredIds.contains(e['id'] as String? ?? '');

    return GestureDetector(
      onTap: () => widget.onEventTap(e),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRegistered ? _kSuccess : _kBorder,
            width: isRegistered ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left accent
            Container(
              width: 4,
              height: 80,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          category.isEmpty ? 'Event' : category,
                          style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Spacer(),
                      if (isRegistered)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: _kSuccessLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle,
                                  color: _kSuccess, size: 10),
                              SizedBox(width: 3),
                              Text('Registered',
                                  style: TextStyle(
                                      color: _kSuccess,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    e['title'] as String? ?? 'Untitled',
                    style: const TextStyle(
                        color: _kTextDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  if (start != null)
                    _row(Icons.calendar_today_outlined, _fmtDate(start)),
                  if (loc.isNotEmpty)
                    _row(Icons.location_on_outlined, loc),
                  if (org.isNotEmpty) _row(Icons.person_outline, 'By $org'),
                ],
              ),
            ),

            const SizedBox(width: 8),
            Column(
              children: [
                // Unsave button
                GestureDetector(
                  onTap: () {
                    _wish.remove(widget.userId, e['id'] as String? ?? '');
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _kPrimaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.bookmark,
                        color: _kPrimary, size: 16),
                  ),
                ),
                const SizedBox(height: 8),
                // Register/Unregister button
                GestureDetector(
                  onTap: () => widget.onToggleRegistration(e),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isRegistered ? _kSuccessLight : _kPrimaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isRegistered
                          ? Icons.check_circle_outline
                          : Icons.add_circle_outline,
                      color: isRegistered ? _kSuccess : _kPrimary,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(icon, size: 12, color: _kTextLight),
          const SizedBox(width: 4),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: _kTextMid, fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    const m = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration:
                  const BoxDecoration(color: _kPrimaryLight, shape: BoxShape.circle),
              child: const Icon(Icons.bookmark_border_outlined,
                  size: 36, color: _kPrimary),
            ),
            const SizedBox(height: 20),
            const Text('No saved events',
                style: TextStyle(
                    color: _kTextDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'Tap the bookmark icon on any event card to save it for later.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _kTextMid, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notLoggedIn() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration:
                  const BoxDecoration(color: _kPrimaryLight, shape: BoxShape.circle),
              child: const Icon(Icons.lock_outline, size: 36, color: _kPrimary),
            ),
            const SizedBox(height: 20),
            const Text('Sign in to save events',
                style: TextStyle(
                    color: _kTextDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
