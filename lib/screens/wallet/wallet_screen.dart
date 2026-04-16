import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/drive_service.dart';
import '../../services/google_auth_service.dart';
import '../../providers/app_state.dart';
import '../../theme/app_colors.dart';
import '../../navigation/app_router.dart';
import 'package:go_router/go_router.dart';

const _bg        = Color(0xFF0D0D0D);
const _surface   = Color(0xFF161616);
const _surfaceEl = Color(0xFF1E1E1E);
const _border    = Color(0xFF2A2A2A);
const _verdigris = Color(0xFF1B998B);
const _chartreuse= Color(0xFFD5FF3F);
const _white     = Color(0xFFFFFFFF);
const _textSec   = Color(0xFF9A9A9A);
const _textTer   = Color(0xFF555555);
const _crimson   = Color(0xFFFF3B30);

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  List<DriveFile> _files    = [];
  bool _loading             = false;
  bool _uploading           = false;
  String? _uploadStatus;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final state = ref.read(appStateProvider);
    if (!state.googleConnected) return;

    setState(() => _loading = true);
    try {
      final files = await DriveService.instance.listFiles();
      setState(() => _files = files);
    } catch (_) {
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUpload({bool camera = false}) async {
    File? file;
    String? fileName;

    try {
      if (camera) {
        final picker = ImagePicker();
        final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
        if (picked == null) return;
        file = File(picked.path);
        fileName = picked.name;
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        );
        if (result == null || result.files.isEmpty) return;
        final f = result.files.first;
        if (f.path == null) return;
        file = File(f.path!);
        fileName = f.name;
      }
    } catch (_) {
      return;
    }

    setState(() { _uploading = true; _uploadStatus = 'Uploading…'; });

    try {
      final ext      = fileName!.split('.').last.toLowerCase();
      final mimeType = ext == 'pdf'
          ? 'application/pdf'
          : 'image/${ext == 'jpg' ? 'jpeg' : ext}';

      setState(() => _uploadStatus = 'Extracting metadata…');
      final metadata = await DriveService.instance.extractMetadata(fileName: fileName);

      setState(() => _uploadStatus = 'Saving to Drive…');
      final uploaded = await DriveService.instance.uploadFile(
        file:     file,
        fileName: fileName,
        mimeType: mimeType,
      );

      if (uploaded != null) {
        setState(() {
          _files.insert(0, uploaded);
          _uploadStatus = 'Uploaded: ${metadata.summary}';
        });

        _showUploadSuccess(metadata);
      }
    } catch (e) {
      setState(() => _uploadStatus = 'Upload failed. Please try again.');
    } finally {
      setState(() => _uploading = false);
    }
  }

  void _showUploadSuccess(DocumentMetadata metadata) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _verdigris.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.check_circle_outline, color: _verdigris, size: 22),
              ),
              const SizedBox(width: 12),
              Text('Document Added', style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w600, color: _white)),
            ]),
            const SizedBox(height: 16),
            _metaRow('Type',    metadata.type.replaceAll('_', ' ').toUpperCase()),
            if (metadata.vendor != null) _metaRow('Vendor', metadata.vendor!),
            if (metadata.amount != null) _metaRow('Amount', 'AED ${metadata.amount!.toStringAsFixed(0)}'),
            if (metadata.date   != null) _metaRow('Date',   metadata.date!),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _surfaceEl, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Text(metadata.summary,
                  style: GoogleFonts.inter(fontSize: 13, color: _textSec, height: 1.5)),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity, height: 48,
                decoration: BoxDecoration(
                  color: _verdigris, borderRadius: BorderRadius.circular(999)),
                child: Center(child: Text('Done',
                    style: GoogleFonts.inter(color: _white, fontWeight: FontWeight.w700))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      SizedBox(width: 70,
          child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: _textTer))),
      Expanded(child: Text(value,
          style: GoogleFonts.inter(fontSize: 13, color: _white, fontWeight: FontWeight.w500))),
    ]),
  );

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add Document', style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w600, color: _white)),
            const SizedBox(height: 20),
            _addOption(Icons.camera_alt_outlined, 'Take a Photo', () {
              Navigator.pop(context);
              _pickAndUpload(camera: true);
            }),
            const SizedBox(height: 12),
            _addOption(Icons.upload_file_outlined, 'Upload from Files', () {
              Navigator.pop(context);
              _pickAndUpload(camera: false);
            }),
          ],
        ),
      ),
    );
  }

  Widget _addOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _surfaceEl,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Row(children: [
          Icon(icon, color: _verdigris, size: 22),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.inter(
              fontSize: 15, color: _white, fontWeight: FontWeight.w500)),
          const Spacer(),
          const Icon(Icons.chevron_right, color: Color(0xFF555555), size: 20),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_uploading) _buildUploadBanner(),
            Expanded(child: state.googleConnected
                ? _buildFileList()
                : _buildConnectPrompt()),
          ],
        ),
      ),
      floatingActionButton: state.googleConnected
          ? FloatingActionButton(
              onPressed: _showAddOptions,
              backgroundColor: _verdigris,
              child: const Icon(Icons.add, color: _white),
            )
          : null,
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Document Wallet',
                  style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: _white)),
              Text('AI-powered document management',
                  style: GoogleFonts.inter(fontSize: 13, color: _textSec)),
            ],
          )),
          if (ref.watch(appStateProvider).googleConnected)
            GestureDetector(
              onTap: _loadFiles,
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _surface, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: const Icon(Icons.refresh_rounded, color: _textSec, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUploadBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _verdigris.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _verdigris.withOpacity(0.3)),
      ),
      child: Row(children: [
        const SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: _verdigris)),
        const SizedBox(width: 12),
        Text(_uploadStatus ?? 'Uploading…',
            style: GoogleFonts.inter(fontSize: 13, color: _verdigris)),
      ]),
    );
  }

  Widget _buildConnectPrompt() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surface, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: _verdigris.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.folder_open_outlined, color: _verdigris, size: 32),
              ),
              const SizedBox(height: 16),
              Text('Connect Google Drive', style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w600, color: _white)),
              const SizedBox(height: 8),
              Text(
                'Connect your Google account to scan, upload and AI-extract metadata from documents.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: _textSec, height: 1.5),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () async {
                  final result = await GoogleAuthService.instance.signIn();
                  if (result.success) {
                    ref.read(appStateProvider.notifier).addGoogleAccount(result.email);
                    _loadFiles();
                  }
                },
                child: Container(
                  width: double.infinity, height: 48,
                  decoration: BoxDecoration(
                    color: _white, borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 22, height: 22,
                        decoration: const BoxDecoration(shape: BoxShape.circle,
                          gradient: SweepGradient(colors: [
                            Color(0xFF4285F4), Color(0xFFEA4335),
                            Color(0xFFFBBC05), Color(0xFF34A853),
                            Color(0xFF4285F4),
                          ]),
                        ),
                        child: const Center(
                          child: Text('G', style: TextStyle(color: Colors.white,
                              fontSize: 12, fontWeight: FontWeight.w900)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text('Connect Google Drive',
                          style: TextStyle(color: Color(0xFF1F1F1F),
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _verdigris));
    }

    if (_files.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_open_outlined, color: _textTer, size: 48),
            const SizedBox(height: 12),
            Text('No documents yet',
                style: GoogleFonts.poppins(fontSize: 16, color: _white)),
            const SizedBox(height: 6),
            Text('Tap + to add your first document',
                style: GoogleFonts.inter(fontSize: 13, color: _textSec)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: _files.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _buildFileCard(_files[i]),
    );
  }

  Widget _buildFileCard(DriveFile file) {
    final ext = file.name.split('.').last.toLowerCase();
    final icon = ext == 'pdf' ? Icons.picture_as_pdf_outlined
        : (ext == 'jpg' || ext == 'jpeg' || ext == 'png')
            ? Icons.image_outlined
            : Icons.insert_drive_file_outlined;
    final iconColor = ext == 'pdf' ? _crimson : _verdigris;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 14, color: _white, fontWeight: FontWeight.w500)),
                if (file.createdTime != null)
                  Text(file.createdTime!.substring(0, 10),
                      style: GoogleFonts.inter(fontSize: 12, color: _textTer)),
              ],
            ),
          ),
          if (file.webViewLink != null)
            GestureDetector(
              onTap: () {/* launch webViewLink */},
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                    color: _surfaceEl, borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _border)),
                child: const Icon(Icons.open_in_new_rounded, color: _textSec, size: 16),
              ),
            ),
        ],
      ),
    );
  }
}
