import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/wallet_document_model.dart';
import '../../services/buddy_api_service.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bgTop     = Color(0xFF002F3A);
const _bgBot     = Color(0xFF000D12);
const _surface   = Color(0xFF0A2A38);
const _surfaceEl = Color(0xFF1A3A4A);
const _border    = Color(0xFF1C4A56);
const _verdigris = Color(0xFF1B998B);
const _white     = Color(0xFFFFFFFF);
const _textSec   = Color(0xFF9A9A9A);
const _textTer   = Color(0xFF4A4A4A);
const _crimson   = Color(0xFFFF3B30);
const _amber     = Color(0xFFCB9A2D);

// ─────────────────────────────────────────────────────────────────────────────
class DocumentWalletScreen extends ConsumerStatefulWidget {
  const DocumentWalletScreen({super.key});

  @override
  ConsumerState<DocumentWalletScreen> createState() =>
      _DocumentWalletScreenState();
}

class _DocumentWalletScreenState
    extends ConsumerState<DocumentWalletScreen> {

  List<WalletDocumentModel> _docs   = [];
  bool    _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final docs = await BuddyApiService.instance.getWalletDocuments();
      if (mounted) setState(() { _docs = docs; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, Color(0xFF001E29), _bgBot],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildInfoBanner(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: _white, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Document Wallet',
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.w700,
                        color: _white)),
                Text('${_docs.length} file${_docs.length == 1 ? '' : 's'} in Drive',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: _textSec)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _load,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: const Icon(Icons.refresh_rounded,
                  color: _textSec, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ── Info banner ────────────────────────────────────────────────────────────
  Widget _buildInfoBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _verdigris.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _verdigris.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.drive_file_move_rounded,
              color: _verdigris, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Files uploaded via Buddy chat are saved to your '
              'Google Drive and indexed here.',
              style: GoogleFonts.inter(
                  fontSize: 12, color: _textSec, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(
              color: _verdigris, strokeWidth: 2));
    }
    if (_error != null) {
      return _buildError();
    }
    if (_docs.isEmpty) {
      return _buildEmpty();
    }

    return RefreshIndicator(
      color: _verdigris,
      backgroundColor: _surface,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        itemCount: _docs.length,
        itemBuilder: (_, i) => _DocCard(
          doc: _docs[i],
          onOpen: _docs[i].webViewLink != null
              ? () => _openLink(_docs[i].webViewLink!)
              : null,
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: _surfaceEl,
              shape: BoxShape.circle,
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.folder_open_rounded,
                color: _textSec, size: 34),
          ),
          const SizedBox(height: 20),
          Text('No documents yet',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600,
                  color: _white)),
          const SizedBox(height: 8),
          Text(
            'Upload a PDF, image, or document in Buddy chat '
            '(tap the + button) to see it here.',
            style: GoogleFonts.inter(
                fontSize: 13, color: _textSec, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded, color: _textSec, size: 48),
          const SizedBox(height: 16),
          Text('Could not load documents',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600,
                  color: _white)),
          const SizedBox(height: 8),
          Text('Check your connection and try again.',
              style: GoogleFonts.inter(
                  fontSize: 13, color: _textSec)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _load,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: _verdigris,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Retry',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: _white,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Document card
// ─────────────────────────────────────────────────────────────────────────────
class _DocCard extends StatelessWidget {
  final WalletDocumentModel doc;
  final VoidCallback? onOpen;

  const _DocCard({required this.doc, this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          // top accent
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: _fileAccentColor(doc.mimeType),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // File-type icon box
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: _fileAccentColor(doc.mimeType).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _fileAccentColor(doc.mimeType).withOpacity(0.3)),
                  ),
                  child: Icon(_fileIcon(doc.mimeType),
                      color: _fileAccentColor(doc.mimeType), size: 22),
                ),
                const SizedBox(width: 12),
                // Info column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doc.filename,
                          style: GoogleFonts.inter(
                              fontSize: 14, fontWeight: FontWeight.w600,
                              color: _white),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(children: [
                        _pill(_mimeLabel(doc.mimeType)),
                        const SizedBox(width: 6),
                        _pill(doc.readableSize),
                        const Spacer(),
                        Text(_dateLabel(doc.createdAt),
                            style: GoogleFonts.inter(
                                fontSize: 11, color: _textTer)),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Open in Drive button
          if (onOpen != null) ...[
            Divider(color: _border, height: 1),
            InkWell(
              onTap: onOpen,
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 11),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.open_in_new_rounded,
                        color: _verdigris, size: 15),
                    const SizedBox(width: 6),
                    Text('Open in Google Drive',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: _verdigris,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pill(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: _surfaceEl,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label,
        style: GoogleFonts.inter(
            fontSize: 10, color: _textSec,
            fontWeight: FontWeight.w500)),
  );

  // ── Helpers ────────────────────────────────────────────────────────────────
  IconData _fileIcon(String mime) {
    if (mime.startsWith('image/'))       return Icons.image_rounded;
    if (mime == 'application/pdf')       return Icons.picture_as_pdf_rounded;
    if (mime.contains('word') ||
        mime.contains('docx') ||
        mime.contains('document'))       return Icons.description_rounded;
    if (mime.contains('sheet') ||
        mime.contains('excel') ||
        mime.contains('spreadsheet'))    return Icons.table_chart_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _fileAccentColor(String mime) {
    if (mime.startsWith('image/'))       return const Color(0xFF42A5F5);
    if (mime == 'application/pdf')       return _crimson;
    if (mime.contains('word') ||
        mime.contains('document'))       return const Color(0xFF5C9DE8);
    if (mime.contains('sheet') ||
        mime.contains('excel') ||
        mime.contains('spreadsheet'))    return const Color(0xFF4CAF50);
    return _amber;
  }

  String _mimeLabel(String mime) {
    if (mime.startsWith('image/'))        return 'Image';
    if (mime == 'application/pdf')        return 'PDF';
    if (mime.contains('word') ||
        mime.contains('document'))        return 'Word';
    if (mime.contains('sheet') ||
        mime.contains('excel') ||
        mime.contains('spreadsheet'))     return 'Excel';
    return 'File';
  }

  String _dateLabel(DateTime? dt) {
    if (dt == null) return '';
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]}';
  }
}
