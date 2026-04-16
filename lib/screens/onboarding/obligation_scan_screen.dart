import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wyle_cos/navigation/app_router.dart';

class ObligationScanScreen extends StatefulWidget {
  const ObligationScanScreen({super.key});

  @override
  State<ObligationScanScreen> createState() => _ObligationScanScreenState();
}

class _ObligationScanScreenState extends State<ObligationScanScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  static const _features = [
    (
      icon: Icons.document_scanner_rounded,
      title: 'Document Scanning',
      description:
          'Automatically extract deadlines and requirements from your documents and emails.',
      color: Color(0xFF1B998B),
    ),
    (
      icon: Icons.mic_rounded,
      title: 'Voice Input',
      description:
          'Speak naturally to add obligations, set reminders, and update your schedule.',
      color: Color(0xFF4285F4),
    ),
    (
      icon: Icons.sync_rounded,
      title: 'Calendar Sync',
      description:
          'Connect Google Calendar, Outlook and more to keep all your commitments in one place.',
      color: Color(0xFFD5FF3F),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF002F3A),
              Color(0xFF001820),
              Color(0xFF000000),
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                const SizedBox(height: 48),
                _buildHeader(),
                const SizedBox(height: 40),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: _buildFeatureList(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
                  child: _buildContinueButton(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF1B998B).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF1B998B).withOpacity(0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1B998B).withOpacity(0.2),
                  blurRadius: 24,
                  offset: Offset.zero,
                ),
              ],
            ),
            child: const Icon(Icons.radar_rounded,
                color: Color(0xFF1B998B), size: 32),
          ),
          const SizedBox(height: 20),
          Text(
            'Scan Obligations',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFFEFFFE),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "We'll help track your important\ndeadlines and commitments.",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xFF8FB8BF),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureList() {
    return ListView.separated(
      itemCount: _features.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final f = _features[index];
        return _FeatureHighlight(
          icon: f.icon,
          title: f.title,
          description: f.description,
          accentColor: f.color,
        );
      },
    );
  }

  Widget _buildContinueButton() {
    return GestureDetector(
      onTap: () => context.go(AppRoutes.ready),
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            colors: [Color(0xFF1B998B), Color(0xFFD5FF3F)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1B998B).withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'Continue →',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF002F3A),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureHighlight extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color accentColor;

  const _FeatureHighlight({
    required this.icon,
    required this.title,
    required this.description,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0A3D4A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1A5060)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accentColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFFEFFFE),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF8FB8BF),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
