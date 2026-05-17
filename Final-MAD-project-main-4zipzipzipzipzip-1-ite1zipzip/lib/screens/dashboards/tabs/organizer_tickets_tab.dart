import 'package:flutter/material.dart';

const _bg = Color(0xFFFAF7F2);
const _white = Color(0xFFFFFFFF);
const _border = Color(0xFFE9E1D6);
const _ink = Color(0xFF1F1A17);
const _muted = Color(0xFF6E6258);
const _accent = Color(0xFFC46A3D);

enum TicketType { vip, standard, student, earlyBird }

extension TicketTypeExt on TicketType {
  String get label {
    switch (this) {
      case TicketType.vip:
        return 'VIP';
      case TicketType.standard:
        return 'Standard';
      case TicketType.student:
        return 'Student';
      case TicketType.earlyBird:
        return 'Early Bird';
    }
  }

  IconData get icon {
    switch (this) {
      case TicketType.vip:
        return Icons.star_outline_rounded;
      case TicketType.standard:
        return Icons.confirmation_num_outlined;
      case TicketType.student:
        return Icons.school_outlined;
      case TicketType.earlyBird:
        return Icons.alarm_outlined;
    }
  }

  Color get color {
    switch (this) {
      case TicketType.vip:
        return const Color(0xFF7C3AED);
      case TicketType.standard:
        return const Color(0xFF1565C0);
      case TicketType.student:
        return const Color(0xFF2E7D32);
      case TicketType.earlyBird:
        return const Color(0xFFC46A3D);
    }
  }
}

class TicketTier {
  final String id;
  final TicketType type;
  double price;
  int total;
  int sold;
  bool salesEnabled;

  TicketTier({
    required this.id,
    required this.type,
    required this.price,
    required this.total,
    required this.sold,
    this.salesEnabled = true,
  });

  int get remaining => (total - sold).clamp(0, total);
  double get revenue => price * sold;
  double get soldPct => total > 0 ? (sold / total).clamp(0.0, 1.0) : 0.0;
}

class OrganizerTicketsTab extends StatefulWidget {
  const OrganizerTicketsTab({super.key});

  @override
  State<OrganizerTicketsTab> createState() => _OrganizerTicketsTabState();
}

class _OrganizerTicketsTabState extends State<OrganizerTicketsTab> {
  final List<TicketTier> _tickets = [
    TicketTier(
        id: 't1',
        type: TicketType.vip,
        price: 299.0,
        total: 50,
        sold: 31),
    TicketTier(
        id: 't2',
        type: TicketType.standard,
        price: 79.0,
        total: 300,
        sold: 187),
    TicketTier(
        id: 't3',
        type: TicketType.student,
        price: 25.0,
        total: 100,
        sold: 42,
        salesEnabled: false),
    TicketTier(
        id: 't4',
        type: TicketType.earlyBird,
        price: 49.0,
        total: 150,
        sold: 150,
        salesEnabled: false),
  ];

  int get _totalSold => _tickets.fold(0, (s, t) => s + t.sold);
  int get _totalCapacity => _tickets.fold(0, (s, t) => s + t.total);
  double get _totalRevenue => _tickets.fold(0.0, (s, t) => s + t.revenue);
  int get _activeTypes =>
      _tickets.where((t) => t.salesEnabled).length;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildMetrics(),
        Expanded(
          child: _tickets.isEmpty ? _buildEmpty() : _buildList(),
        ),
        _buildAddButton(),
      ],
    );
  }

  Widget _buildMetrics() {
    return Container(
      color: _white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          _metric('Total Sold', '$_totalSold / $_totalCapacity',
              Icons.confirmation_num_outlined, _ink),
          const SizedBox(width: 8),
          _metric('Revenue',
              '£${_totalRevenue >= 1000 ? '${(_totalRevenue / 1000).toStringAsFixed(1)}k' : _totalRevenue.toStringAsFixed(0)}',
              Icons.attach_money_outlined, const Color(0xFF2E7D32)),
          const SizedBox(width: 8),
          _metric('Active Sales', '$_activeTypes types',
              Icons.sell_outlined, _accent),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(height: 5),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
            Text(label,
                style: const TextStyle(
                    color: _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: _tickets.length,
      itemBuilder: (_, i) => _TicketCard(
        ticket: _tickets[i],
        onEdit: () => _showTicketSheet(existing: _tickets[i]),
        onToggle: () => setState(
            () => _tickets[i].salesEnabled = !_tickets[i].salesEnabled),
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
              decoration: BoxDecoration(
                color: _border.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.confirmation_num_outlined,
                  size: 40, color: _muted),
            ),
            const SizedBox(height: 16),
            const Text('No ticket types yet',
                style: TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text(
              'Create your first ticket type to start selling.',
              style: TextStyle(color: _muted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: const BoxDecoration(
        color: _white,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showTicketSheet(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create Ticket Type',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
    );
  }

  void _showTicketSheet({TicketTier? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _TicketFormSheet(
        existing: existing,
        usedTypes: _tickets
            .where((t) => existing == null || t.id != existing.id)
            .map((t) => t.type)
            .toSet(),
        onSaved: (tier) {
          setState(() {
            if (existing != null) {
              final idx =
                  _tickets.indexWhere((t) => t.id == existing.id);
              if (idx != -1) _tickets[idx] = tier;
            } else {
              _tickets.add(tier);
            }
          });
        },
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final TicketTier ticket;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  const _TicketCard({
    required this.ticket,
    required this.onEdit,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final t = ticket;
    final color = t.type.color;
    final isSoldOut = t.remaining == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: t.salesEnabled ? _border : _border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: _ink.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Opacity(
        opacity: t.salesEnabled ? 1.0 : 0.65,
        child: Column(
          children: [
            // ── Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(t.type.icon, size: 20, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(t.type.label,
                                style: const TextStyle(
                                    color: _ink,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(width: 6),
                            if (isSoldOut)
                              _badge('SOLD OUT', Colors.redAccent),
                            if (!t.salesEnabled && !isSoldOut)
                              _badge('PAUSED', _muted),
                          ],
                        ),
                        Text('£${t.price.toStringAsFixed(2)} per ticket',
                            style: const TextStyle(
                                color: _muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon:
                        const Icon(Icons.more_vert, size: 18, color: _muted),
                    color: _white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onSelected: (v) {
                      if (v == 'edit') onEdit();
                      if (v == 'toggle') onToggle();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          const Icon(Icons.edit_outlined,
                              size: 15, color: _ink),
                          const SizedBox(width: 8),
                          const Text('Edit Ticket',
                              style: TextStyle(color: _ink, fontSize: 13)),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Row(children: [
                          Icon(
                              t.salesEnabled
                                  ? Icons.pause_circle_outline
                                  : Icons.play_circle_outline,
                              size: 15,
                              color:
                                  t.salesEnabled ? _muted : const Color(0xFF2E7D32)),
                          const SizedBox(width: 8),
                          Text(
                              t.salesEnabled
                                  ? 'Pause Sales'
                                  : 'Resume Sales',
                              style: TextStyle(
                                  color: t.salesEnabled
                                      ? _muted
                                      : const Color(0xFF2E7D32),
                                  fontSize: 13)),
                        ]),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Progress bar
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${t.sold} sold · ${t.remaining} remaining',
                        style: const TextStyle(
                            color: _muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${(t.soldPct * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: t.soldPct,
                      minHeight: 6,
                      backgroundColor: color.withOpacity(0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(
                          isSoldOut ? Colors.redAccent : color),
                    ),
                  ),
                ],
              ),
            ),

            // ── Stats row
            Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.04),
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  _statItem(
                    'Revenue',
                    '£${t.revenue >= 1000 ? '${(t.revenue / 1000).toStringAsFixed(1)}k' : t.revenue.toStringAsFixed(0)}',
                    color,
                  ),
                  _vDivider(),
                  _statItem('Total', '${t.total}', _muted),
                  _vDivider(),
                  _statItem(
                    'Status',
                    isSoldOut
                        ? 'Sold Out'
                        : t.salesEnabled
                            ? 'On Sale'
                            : 'Paused',
                    isSoldOut
                        ? Colors.redAccent
                        : t.salesEnabled
                            ? const Color(0xFF2E7D32)
                            : _muted,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4)),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: _muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
        width: 1,
        height: 28,
        color: _border,
        margin: const EdgeInsets.symmetric(horizontal: 10),
      );
}

class _TicketFormSheet extends StatefulWidget {
  final TicketTier? existing;
  final Set<TicketType> usedTypes;
  final void Function(TicketTier) onSaved;

  const _TicketFormSheet({
    required this.existing,
    required this.usedTypes,
    required this.onSaved,
  });

  @override
  State<_TicketFormSheet> createState() => _TicketFormSheetState();
}

class _TicketFormSheetState extends State<_TicketFormSheet> {
  late TicketType _type;
  final _priceCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _soldCtrl = TextEditingController();
  bool _salesEnabled = true;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? _firstAvailableType();
    _priceCtrl.text =
        e != null ? e.price.toStringAsFixed(2) : '';
    _totalCtrl.text = e != null ? '${e.total}' : '';
    _soldCtrl.text = e != null ? '${e.sold}' : '0';
    _salesEnabled = e?.salesEnabled ?? true;
  }

  TicketType _firstAvailableType() {
    for (final t in TicketType.values) {
      if (!widget.usedTypes.contains(t)) return t;
    }
    return TicketType.standard;
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _totalCtrl.dispose();
    _soldCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final tier = TicketTier(
      id: widget.existing?.id ??
          'ticket_${DateTime.now().millisecondsSinceEpoch}',
      type: _type,
      price: double.tryParse(_priceCtrl.text) ?? 0,
      total: int.tryParse(_totalCtrl.text) ?? 0,
      sold: int.tryParse(_soldCtrl.text) ?? 0,
      salesEnabled: _salesEnabled,
    );
    widget.onSaved(tier);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final availableTypes = TicketType.values
        .where((t) => !widget.usedTypes.contains(t) || t == _type)
        .toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isEdit ? 'Edit Ticket Type' : 'Create Ticket Type',
                      style: const TextStyle(
                          color: _ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: _muted),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Type selector
              const Text('Ticket Type',
                  style: TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableTypes.map((t) {
                  final selected = _type == t;
                  return GestureDetector(
                    onTap: () => setState(() => _type = t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? t.color.withOpacity(0.1)
                            : _bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color:
                                selected ? t.color : _border,
                            width: selected ? 1.5 : 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(t.icon,
                              size: 15,
                              color:
                                  selected ? t.color : _muted),
                          const SizedBox(width: 6),
                          Text(t.label,
                              style: TextStyle(
                                  color: selected
                                      ? t.color
                                      : _muted,
                                  fontSize: 12,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Price
              _formField(_priceCtrl, 'Price (£)',
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    if (n == null || n < 0) {
                      return 'Enter a valid price (0 for free)';
                    }
                    return null;
                  }),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _formField(
                      _totalCtrl,
                      'Total Tickets',
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n <= 0) {
                          return 'Must be > 0';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _formField(
                      _soldCtrl,
                      'Sold So Far',
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        final total =
                            int.tryParse(_totalCtrl.text) ?? 0;
                        if (n == null || n < 0) {
                          return 'Must be ≥ 0';
                        }
                        if (n > total) {
                          return 'Cannot exceed total';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Toggle
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.sell_outlined,
                        size: 18,
                        color:
                            _salesEnabled ? _accent : _muted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sales Active',
                            style: TextStyle(
                                color:
                                    _salesEnabled ? _ink : _muted,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                          Text(
                            _salesEnabled
                                ? 'Tickets are currently on sale.'
                                : 'Sales are paused for this ticket.',
                            style: const TextStyle(
                                color: _muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _salesEnabled,
                      onChanged: (v) =>
                          setState(() => _salesEnabled = v),
                      activeColor: _accent,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  isEdit ? 'Save Changes' : 'Create Ticket',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formField(
    TextEditingController ctrl,
    String label, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: _ink, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _muted, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFF7F7F7),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _ink, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }
}
