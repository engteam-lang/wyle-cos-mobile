import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wyle_cos/models/obligation_model.dart';
import 'package:wyle_cos/providers/app_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colour constants
// ─────────────────────────────────────────────────────────────────────────────
const Color _bgDark      = Color(0xFF0D0D0D);
const Color _surfaceDark = Color(0xFF161616);
const Color _surfaceEl   = Color(0xFF1E1E1E);
const Color _verdigris   = Color(0xFF1B998B);
const Color _chartreuse  = Color(0xFFD5FF3F);
const Color _chartreuseB = Color(0xFFA8CC00);
const Color _crimson     = Color(0xFFFF3B30);
const Color _orange      = Color(0xFFFF9500);
const Color _white       = Color(0xFFFFFFFF);
const Color _textSec     = Color(0xFF9A9A9A);
const Color _textTer     = Color(0xFF555555);
const Color _border      = Color(0xFF2A2A2A);

// ─────────────────────────────────────────────────────────────────────────────
// Obligation types available when adding
// ─────────────────────────────────────────────────────────────────────────────
const _kObligationTypes = [
  'visa',
  'emirates_id',
  'car_registration',
  'insurance',
  'school_fee',
  'mortgage_emi',
  'subscription',
  'medical',
  'document',
  'bill',
  'custom',
];

const _kTypeLabels = {
  'visa':             'Visa',
  'emirates_id':      'Emirates ID',
  'car_registration': 'Car Registration',
  'insurance':        'Insurance',
  'school_fee':       'School Fee',
  'mortgage_emi':     'Mortgage / EMI',
  'subscription':     'Subscription',
  'medical':          'Medical',
  'document':         'Document',
  'bill':             'Bill',
  'custom':           'Custom',
};

// ─────────────────────────────────────────────────────────────────────────────
// ObligationsScreen
// ─────────────────────────────────────────────────────────────────────────────
class ObligationsScreen extends ConsumerStatefulWidget {
  const ObligationsScreen({super.key});

  @override
  ConsumerState<ObligationsScreen> createState() => _ObligationsScreenState();
}

class _ObligationsScreenState extends ConsumerState<ObligationsScreen> {
  String _filterRisk = 'all'; // 'all' | 'high' | 'medium' | 'low'
  bool _showResolved = false;

  // ── helpers ──────────────────────────────────────────────────────────────────
  Color _riskColor(String risk) {
    switch (risk) {
      case 'high':   return _crimson;
      case 'medium': return _orange;
      default:       return _verdigris;
    }
  }

  String _daysLabel(int days) => days == 0 ? 'TODAY' : '${days}d';

  List<ObligationModel> _filtered(List<ObligationModel> all) {
    var list = _showResolved
        ? all
        : all.where((o) => o.status != 'completed').toList();
    if (_filterRisk != 'all') {
      list = list.where((o) => o.risk == _filterRisk).toList();
    }
    return list;
  }

  // ── modals ────────────────────────────────────────────────────────────────────
  void _showDetailModal(ObligationModel ob) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DetailModal(
        obligation: ob,
        onMarkDone: () {
          ref.read(appStateProvider.notifier).updateObligation(
                ob.id,
                (o) => o.copyWith(status: 'completed'),
              );
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showAddModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AddModal(
        onAdd: (ob) {
          ref.read(appStateProvider.notifier).addObligation(ob);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state       = ref.watch(appStateProvider);
    final allActive   = ref.watch(activeObligationsProvider);
    final allObs      = state.obligations;
    final displayed   = _filtered(allObs);
    final activeCount = allActive.length;

    return Scaffold(
      backgroundColor: _bgDark,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Automations',
                          style: GoogleFonts.inter(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: _white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$activeCount active obligation${activeCount != 1 ? 's' : ''}',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: _textSec),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _showAddModal,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _verdigris,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add, color: _white, size: 22),
                    ),
                  ),
                ],
              ),
            ),

            // ── Filter tabs ─────────────────────────────────────────────────
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: ['all', 'high', 'medium', 'low'].map((f) {
                  final active = _filterRisk == f;
                  return GestureDetector(
                    onTap: () => setState(() => _filterRisk = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: active
                            ? _verdigris.withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active ? _verdigris : _border,
                        ),
                      ),
                      child: Text(
                        f.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: active ? _verdigris : _textSec,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 14),

            // ── List ────────────────────────────────────────────────────────
            Expanded(
              child: displayed.isEmpty
                  ? _buildEmpty()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: displayed.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, i) =>
                          _buildCard(displayed[i]),
                    ),
            ),

            // ── Resolved toggle ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: GestureDetector(
                onTap: () =>
                    setState(() => _showResolved = !_showResolved),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _showResolved
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 15,
                      color: _textTer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _showResolved
                          ? 'Hide resolved'
                          : 'Show resolved obligations',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: _textTer),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddModal,
        backgroundColor: _verdigris,
        child: const Icon(Icons.add, color: _white),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('✅', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            _filterRisk == 'all'
                ? 'No obligations yet'
                : 'No ${_filterRisk} risk items',
            style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w600, color: _white),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap + to add one',
            style: GoogleFonts.inter(fontSize: 13, color: _textSec),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(ObligationModel ob) {
    final rc = _riskColor(ob.risk);
    final done = ob.status == 'completed';

    return GestureDetector(
      onTap: () => _showDetailModal(ob),
      child: Opacity(
        opacity: done ? 0.5 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: _surfaceDark,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // ── Left colour strip ──────────────────────────────────────
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: rc,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                ),
                // ── Content ────────────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ob.emoji,
                            style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ob.title,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _white,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                ob.executionPath,
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: _textSec),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (ob.amount != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'AED ${ob.amount!.toStringAsFixed(0)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _chartreuse,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: rc.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                done ? 'DONE' : _daysLabel(ob.daysUntil),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: done ? _textSec : rc,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: rc.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                ob.risk.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: rc,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail modal
// ─────────────────────────────────────────────────────────────────────────────
class _DetailModal extends StatelessWidget {
  final ObligationModel obligation;
  final VoidCallback onMarkDone;

  const _DetailModal({required this.obligation, required this.onMarkDone});

  Color _riskColor(String risk) {
    switch (risk) {
      case 'high':   return _crimson;
      case 'medium': return _orange;
      default:       return _verdigris;
    }
  }

  String _daysLabel(int days) {
    if (days == 0) return 'Due today';
    return 'Due in $days day${days != 1 ? 's' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final ob = obligation;
    final rc = _riskColor(ob.risk);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: _surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _textTer,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Emoji + title
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ob.emoji, style: const TextStyle(fontSize: 36)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ob.title,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _badge(ob.risk.toUpperCase(), rc),
                        const SizedBox(width: 8),
                        _badge(_daysLabel(ob.daysUntil), _textSec),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Details
          _detailRow('Execution', ob.executionPath),
          if (ob.notes != null) ...[
            const SizedBox(height: 10),
            _detailRow('Notes', ob.notes!),
          ],
          if (ob.amount != null) ...[
            const SizedBox(height: 10),
            _detailRow(
                'Amount', 'AED ${ob.amount!.toStringAsFixed(0)}'),
          ],
          if (ob.source != null) ...[
            const SizedBox(height: 10),
            _detailRow('Source', ob.source!),
          ],
          const SizedBox(height: 24),

          // Mark as Done
          if (ob.status != 'completed') ...[
            GestureDetector(
              onTap: onMarkDone,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_verdigris, Color(0xFF157A6E)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: Text(
                    '✓  Mark as Done',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Close
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Center(
                child: Text(
                  'Close',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textSec,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      );

  Widget _detailRow(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: _textTer,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 14, color: _white),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Obligation modal
// ─────────────────────────────────────────────────────────────────────────────
class _AddModal extends StatefulWidget {
  final void Function(ObligationModel) onAdd;

  const _AddModal({required this.onAdd});

  @override
  State<_AddModal> createState() => _AddModalState();
}

class _AddModalState extends State<_AddModal> {
  final _titleCtrl         = TextEditingController();
  final _daysCtrl          = TextEditingController(text: '7');
  final _amountCtrl        = TextEditingController();
  final _executionCtrl     = TextEditingController();
  final _notesCtrl         = TextEditingController();

  String _type = 'custom';
  String _risk = 'medium';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _daysCtrl.dispose();
    _amountCtrl.dispose();
    _executionCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_titleCtrl.text.trim().isEmpty) return;
    final ob = ObligationModel(
      id:            DateTime.now().millisecondsSinceEpoch.toString(),
      emoji:         emojiForType(_type),
      title:         _titleCtrl.text.trim(),
      type:          _type,
      daysUntil:     int.tryParse(_daysCtrl.text) ?? 7,
      risk:          _risk,
      amount:        double.tryParse(_amountCtrl.text),
      status:        'active',
      executionPath: _executionCtrl.text.trim().isNotEmpty
          ? _executionCtrl.text.trim()
          : 'Handle manually',
      notes:         _notesCtrl.text.trim().isNotEmpty
          ? _notesCtrl.text.trim()
          : null,
      source:        'manual',
    );
    widget.onAdd(ob);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _surfaceDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _textTer,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Add Obligation',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _white,
                ),
              ),
              const SizedBox(height: 20),

              _label('TITLE'),
              _field(_titleCtrl, 'e.g. Emirates ID Renewal'),
              const SizedBox(height: 14),

              _label('TYPE'),
              _dropdownField(),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('DAYS UNTIL'),
                        _field(_daysCtrl, '7',
                            keyboardType: TextInputType.number),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('RISK'),
                        _riskPicker(),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _label('AMOUNT (AED, optional)'),
              _field(_amountCtrl, '0',
                  keyboardType: TextInputType.number),
              const SizedBox(height: 14),

              _label('EXECUTION PATH'),
              _field(_executionCtrl, 'How to handle this?'),
              const SizedBox(height: 14),

              _label('NOTES (optional)'),
              _field(_notesCtrl, 'Any extra details...', maxLines: 2),
              const SizedBox(height: 24),

              GestureDetector(
                onTap: _submit,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_verdigris, Color(0xFF157A6E)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Center(
                    child: Text(
                      'Add Obligation',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: _textTer,
            letterSpacing: 1.1,
          ),
        ),
      );

  Widget _field(
    TextEditingController ctrl,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: GoogleFonts.inter(fontSize: 14, color: _white),
        cursorColor: _verdigris,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(fontSize: 14, color: _textTer),
          filled: true,
          fillColor: _surfaceEl,
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
            borderSide: const BorderSide(color: _verdigris),
          ),
        ),
      );

  Widget _dropdownField() => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: _surfaceEl,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _type,
            isExpanded: true,
            dropdownColor: _surfaceEl,
            style: GoogleFonts.inter(fontSize: 14, color: _white),
            items: _kObligationTypes
                .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(_kTypeLabels[t] ?? t),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _type = v);
            },
          ),
        ),
      );

  Widget _riskPicker() {
    return Row(
      children: ['high', 'medium', 'low'].map((r) {
        final selected = _risk == r;
        final color = r == 'high'
            ? _crimson
            : r == 'medium'
                ? _orange
                : _verdigris;
        return GestureDetector(
          onTap: () => setState(() => _risk = r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(right: 6),
            padding:
                const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? color.withOpacity(0.2) : _surfaceEl,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: selected ? color : _border),
            ),
            child: Text(
              r[0].toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? color : _textTer,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
