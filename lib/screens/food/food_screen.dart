import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/chat_message_model.dart';
import '../../providers/app_state.dart';
import '../../services/ai_service.dart';

const _bg        = Color(0xFF0D0D0D);
const _surface   = Color(0xFF161616);
const _surfaceEl = Color(0xFF1E1E1E);
const _border    = Color(0xFF2A2A2A);
const _verdigris = Color(0xFF1B998B);
const _chartreuse= Color(0xFFD5FF3F);
const _chartrB   = Color(0xFFA8CC00);
const _salmon    = Color(0xFFFF9F8A);
const _white     = Color(0xFFFFFFFF);
const _textSec   = Color(0xFF9A9A9A);
const _textTer   = Color(0xFF555555);

enum _FoodStep { intent, options, confirm }

class FoodScreen extends ConsumerStatefulWidget {
  const FoodScreen({super.key});

  @override
  ConsumerState<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends ConsumerState<FoodScreen> {
  _FoodStep _step        = _FoodStep.intent;
  String    _intent      = '';
  bool      _loading     = false;
  List<FoodOptionModel> _options = [];
  FoodOptionModel? _selected;

  final TextEditingController _intentCtrl = TextEditingController();

  Future<void> _generateOptions() async {
    final text = _intentCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() { _intent = text; _loading = true; });

    try {
      final state = ref.read(appStateProvider);
      final dietary = state.user?.preferences.dietary.join(', ') ?? 'no restrictions';

      final response = await AiService.instance.complete(
        systemPrompt: '''You are a Dubai food ordering assistant.
Generate exactly 3 food/restaurant options based on the user's request.
Dietary: $dietary
Return a JSON array:
[{
  "id": "1",
  "name": "Restaurant or Dish Name",
  "cuisine": "Cuisine type",
  "rating": 4.5,
  "deliveryTime": "25-30 mins",
  "priceRange": "AED 40-80",
  "tags": ["tag1","tag2"],
  "partner": "Talabat|Careem Food|Noon Food",
  "certaintyScore": 90
}]
Only return valid JSON.''',
        userMessage: 'User wants: $text',
        maxTokens: 600,
      );

      final list = AiService.parseJsonArray(response);
      if (list != null) {
        setState(() {
          _options = list.map((j) => FoodOptionModel.fromJson(j)).toList();
          _step    = _FoodStep.options;
        });
      }
    } catch (_) {
      // Fallback options
      setState(() {
        _options = _fallbackOptions();
        _step    = _FoodStep.options;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  List<FoodOptionModel> _fallbackOptions() => [
    const FoodOptionModel(id:'1', name:'Zaatar w Zeit', cuisine:'Lebanese',
        rating:4.6, deliveryTime:'20-25 mins', priceRange:'AED 35-70',
        tags:['Healthy','Wraps','Manakeesh'], partner:'Talabat', certaintyScore:92),
    const FoodOptionModel(id:'2', name:'PF Chang\'s', cuisine:'Asian',
        rating:4.4, deliveryTime:'30-40 mins', priceRange:'AED 60-120',
        tags:['Noodles','Stir Fry','Wok'], partner:'Careem Food', certaintyScore:85),
    const FoodOptionModel(id:'3', name:'CRUST', cuisine:'Italian',
        rating:4.7, deliveryTime:'25-35 mins', priceRange:'AED 55-100',
        tags:['Pizza','Pasta','Calzone'], partner:'Noon Food', certaintyScore:88),
  ];

  void _selectOption(FoodOptionModel opt) {
    setState(() { _selected = opt; _step = _FoodStep.confirm; });
  }

  void _confirm() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Order Confirmed! 🎉',
            style: GoogleFonts.poppins(color: _white, fontWeight: FontWeight.w600)),
        content: Text(
          'Your order from ${_selected?.name} has been placed via ${_selected?.partner}.\nEstimated delivery: ${_selected?.deliveryTime}',
          style: GoogleFonts.inter(color: _textSec, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            child: Text('Done', style: TextStyle(color: _verdigris)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: _surface, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border)),
            child: const Icon(Icons.close, color: _white, size: 20),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order Food', style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w700, color: _white)),
            // Step indicator
            Row(children: [
              _stepDot(1, 'Intent',  _step.index >= 0),
              _stepLine(_step.index >= 1),
              _stepDot(2, 'Options', _step.index >= 1),
              _stepLine(_step.index >= 2),
              _stepDot(3, 'Confirm', _step.index >= 2),
            ]),
          ],
        )),
      ]),
    );
  }

  Widget _stepDot(int n, String label, bool active) {
    return Column(children: [
      Container(
        width: 18, height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? _verdigris : _border,
        ),
        child: Center(child: Text('$n',
            style: TextStyle(color: _white, fontSize: 10, fontWeight: FontWeight.w700))),
      ),
    ]);
  }

  Widget _stepLine(bool active) => Expanded(
    child: Container(height: 2, color: active ? _verdigris : _border,
        margin: const EdgeInsets.symmetric(horizontal: 4)),
  );

  Widget _buildBody() {
    switch (_step) {
      case _FoodStep.intent:   return _buildIntentStep();
      case _FoodStep.options:  return _buildOptionsStep();
      case _FoodStep.confirm:  return _buildConfirmStep();
    }
  }

  Widget _buildIntentStep() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text('What are you in the mood for?', style: GoogleFonts.poppins(
              fontSize: 22, fontWeight: FontWeight.w600, color: _white,
              height: 1.3), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Describe what you want and Wyle will find the best options.',
              style: GoogleFonts.inter(fontSize: 13, color: _textSec),
              textAlign: TextAlign.center),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              color: _surface, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: TextField(
              controller: _intentCtrl,
              maxLines: 3,
              style: GoogleFonts.inter(color: _white, fontSize: 15, height: 1.5),
              decoration: InputDecoration(
                hintText: 'e.g. "Healthy Lebanese wrap near JBR"',
                hintStyle: GoogleFonts.inter(color: _textTer, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _loading ? null : _generateOptions,
            child: Container(
              width: double.infinity, height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_verdigris, Color(0xFF157A6E)]),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Center(child: _loading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: _white))
                  : Text('Find My Food →', style: GoogleFonts.inter(
                      fontSize: 16, color: _white, fontWeight: FontWeight.w800))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('3 OPTIONS FOR YOU', style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: _textTer, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          ..._options.map((opt) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildOptionCard(opt),
          )),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(() { _step = _FoodStep.intent; _options = []; }),
            child: Container(
              width: double.infinity, height: 44,
              decoration: BoxDecoration(
                color: _surfaceEl, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Center(child: Text('Start Over',
                  style: GoogleFonts.inter(color: _textSec, fontSize: 14))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(FoodOptionModel opt) {
    final confColor = opt.certaintyScore >= 90 ? _chartreuse : _verdigris;
    return GestureDetector(
      onTap: () => _selectOption(opt),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(opt.name, style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600, color: _white))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: confColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: Text('${opt.certaintyScore.toInt()}%',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: confColor, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 6),
            Text(opt.cuisine, style: GoogleFonts.inter(fontSize: 13, color: _textSec)),
            const SizedBox(height: 10),
            Row(children: [
              _iconMeta(Icons.star_rounded, '${opt.rating}', _chartreuse),
              const SizedBox(width: 14),
              _iconMeta(Icons.timer_outlined, opt.deliveryTime, _textSec),
              const SizedBox(width: 14),
              _iconMeta(Icons.attach_money, opt.priceRange, _textSec),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6,
              children: opt.tags.map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: _surfaceEl, borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _border)),
                child: Text(t, style: GoogleFonts.inter(
                    fontSize: 11, color: _textTer)),
              )).toList(),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity, height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_chartreuse, _chartrB]),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Center(child: Text('Select  →', style: GoogleFonts.inter(
                  color: _bg, fontSize: 13, fontWeight: FontWeight.w800))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconMeta(IconData icon, String text, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: 4),
      Text(text, style: GoogleFonts.inter(fontSize: 12, color: color)),
    ],
  );

  Widget _buildConfirmStep() {
    final opt = _selected!;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text('Confirm Your Order', style: GoogleFonts.poppins(
              fontSize: 22, fontWeight: FontWeight.w600, color: _white)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _surface, borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(opt.name, style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w700, color: _white)),
                const SizedBox(height: 6),
                Text(opt.cuisine, style: GoogleFonts.inter(fontSize: 14, color: _textSec)),
                const SizedBox(height: 16),
                _confirmRow('Delivery Time', opt.deliveryTime),
                _confirmRow('Price Range', opt.priceRange),
                _confirmRow('Via', opt.partner),
                _confirmRow('Your request', _intent),
              ],
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _confirm,
            child: Container(
              width: double.infinity, height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_salmon, Color(0xFFFF6B6B)]),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Center(child: Text('Place Order →', style: GoogleFonts.inter(
                  color: _white, fontSize: 16, fontWeight: FontWeight.w800))),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(() => _step = _FoodStep.options),
            child: Container(
              width: double.infinity, height: 44,
              decoration: BoxDecoration(
                color: _surfaceEl, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Center(child: Text('← Back to Options',
                  style: GoogleFonts.inter(color: _textSec, fontSize: 14))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _confirmRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      SizedBox(width: 110, child: Text(label,
          style: GoogleFonts.inter(fontSize: 12, color: _textTer))),
      Expanded(child: Text(value, style: GoogleFonts.inter(
          fontSize: 13, color: _white, fontWeight: FontWeight.w500))),
    ]),
  );
}

// Minimal FoodOptionModel for this screen
class FoodOptionModel {
  final String id, name, cuisine, deliveryTime, priceRange, partner;
  final double rating, certaintyScore;
  final List<String> tags;
  const FoodOptionModel({
    required this.id, required this.name, required this.cuisine,
    required this.rating, required this.deliveryTime, required this.priceRange,
    required this.tags, required this.partner, required this.certaintyScore,
  });
  factory FoodOptionModel.fromJson(Map<String, dynamic> j) => FoodOptionModel(
    id:             j['id'] ?? '',
    name:           j['name'] ?? '',
    cuisine:        j['cuisine'] ?? '',
    rating:         (j['rating'] as num?)?.toDouble() ?? 4.0,
    deliveryTime:   j['deliveryTime'] ?? '30 mins',
    priceRange:     j['priceRange'] ?? '',
    tags:           List<String>.from(j['tags'] ?? []),
    partner:        j['partner'] ?? 'Talabat',
    certaintyScore: (j['certaintyScore'] as num?)?.toDouble() ?? 80,
  );
}

const _bg2 = _bg;
