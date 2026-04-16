import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wyle_cos/navigation/app_router.dart';
import 'package:wyle_cos/providers/app_state.dart';
import 'package:wyle_cos/models/user_model.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  bool _isCreateMode = true;
  bool _isLoading = false;
  String? _errorMessage;

  final _nameController    = TextEditingController();
  final _emailController   = TextEditingController();
  final _locationController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _locationController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _switchMode(bool createMode) {
    if (_isCreateMode == createMode) return;
    setState(() {
      _isCreateMode = createMode;
      _errorMessage = null;
    });
    _fadeController.reset();
    _fadeController.forward();
  }

  bool _validate() {
    if (_isCreateMode) {
      if (_nameController.text.trim().isEmpty ||
          _emailController.text.trim().isEmpty ||
          _locationController.text.trim().isEmpty ||
          _passwordController.text.isEmpty) {
        setState(() => _errorMessage = 'Please fill in all fields.');
        return false;
      }
    } else {
      if (_emailController.text.trim().isEmpty ||
          _passwordController.text.isEmpty) {
        setState(() => _errorMessage = 'Please enter your email and password.');
        return false;
      }
    }
    setState(() => _errorMessage = null);
    return true;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    setState(() => _isLoading = true);

    // Demo mode — accept any credentials
    await Future.delayed(const Duration(milliseconds: 800));

    final mockToken = 'demo_token_${DateTime.now().millisecondsSinceEpoch}';
    final mockUser = UserModel(
      id: 'demo_user_001',
      name: _isCreateMode
          ? _nameController.text.trim()
          : _emailController.text.split('@').first,
      email: _emailController.text.trim(),
      onboardingComplete: false,
      onboardingStep: 1,
      preferences: const UserPreferences(),
      autonomyTier: 1,
      insights: const UserInsights(),
    );

    // Persist to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', mockToken);
    await prefs.setString('user_email', mockUser.email);
    await prefs.setString('user_name', mockUser.name);

    // Update app state
    await ref.read(appStateProvider.notifier).setAuth(mockToken, mockUser);

    if (mounted) {
      setState(() => _isLoading = false);
      context.go(AppRoutes.preparation);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));

    final mockToken = 'google_demo_token_${DateTime.now().millisecondsSinceEpoch}';
    final mockUser = UserModel(
      id: 'google_demo_user_001',
      name: 'Demo User',
      email: 'demo@gmail.com',
      onboardingComplete: false,
      onboardingStep: 1,
      preferences: const UserPreferences(),
      autonomyTier: 1,
      insights: const UserInsights(),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', mockToken);
    await prefs.setString('user_email', mockUser.email);
    await prefs.setString('user_name', mockUser.name);

    await ref.read(appStateProvider.notifier).setAuth(mockToken, mockUser);

    if (mounted) {
      setState(() => _isLoading = false);
      context.go(AppRoutes.preparation);
    }
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
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const SizedBox(height: 40),
                _buildLogo(),
                const SizedBox(height: 32),
                _buildToggle(),
                const SizedBox(height: 28),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildFields(),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  _buildErrorBox(),
                ],
                const SizedBox(height: 24),
                _buildPrimaryButton(),
                const SizedBox(height: 24),
                _buildDivider(),
                const SizedBox(height: 24),
                _buildGoogleButton(),
                const SizedBox(height: 40),
                _buildFooter(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Text(
          'WYLE',
          style: GoogleFonts.poppins(
            fontSize: 36,
            fontWeight: FontWeight.w200,
            color: const Color(0xFFFEFFFE),
            letterSpacing: 12,
            shadows: [
              const Shadow(
                color: Color(0x881B998B),
                blurRadius: 20,
                offset: Offset.zero,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _isCreateMode ? 'Create your account' : 'Welcome back',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: const Color(0xFF8FB8BF),
          ),
        ),
      ],
    );
  }

  Widget _buildToggle() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF0A3D4A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF1A5060)),
      ),
      child: Row(
        children: [
          _ToggleButton(
            label: 'Create Account',
            active: _isCreateMode,
            onTap: () => _switchMode(true),
          ),
          _ToggleButton(
            label: 'Sign In',
            active: !_isCreateMode,
            onTap: () => _switchMode(false),
          ),
        ],
      ),
    );
  }

  Widget _buildFields() {
    return Column(
      children: [
        if (_isCreateMode) ...[
          _InputField(
            controller: _nameController,
            hint: 'Full Name',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 14),
        ],
        _InputField(
          controller: _emailController,
          hint: 'Email Address',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        if (_isCreateMode) ...[
          const SizedBox(height: 14),
          _InputField(
            controller: _locationController,
            hint: 'Location (City, Country)',
            icon: Icons.location_on_outlined,
          ),
        ],
        const SizedBox(height: 14),
        _InputField(
          controller: _passwordController,
          hint: 'Password',
          icon: Icons.lock_outline_rounded,
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: const Color(0xFF4A7A85),
              size: 20,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFD7263D).withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFD7263D).withOpacity(0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFD7263D), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFFD7263D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _submit,
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
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF002F3A),
                  ),
                )
              : Text(
                  _isCreateMode
                      ? 'Continue to Dashboard ›'
                      : 'Sign In ›',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF002F3A),
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: const Color(0xFF1A5060),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF4A7A85),
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: const Color(0xFF1A5060),
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _googleSignIn,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFFFEFFFE),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google G icon composed of colored circles
            SizedBox(
              width: 24,
              height: 24,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFEA4335),
                        width: 3,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      color: const Color(0xFFFEFFFE),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF4285F4),
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Sign in with Google',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_outline_rounded,
            color: Color(0xFF4A7A85), size: 14),
        const SizedBox(width: 6),
        Text(
          'Your information is encrypted and secure.',
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: const Color(0xFF4A7A85),
          ),
        ),
      ],
    );
  }
}

// ── Subwidgets ────────────────────────────────────────────────────────────────

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF1B998B) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight:
                    active ? FontWeight.w600 : FontWeight.w400,
                color: active
                    ? const Color(0xFFFEFFFE)
                    : const Color(0xFF8FB8BF),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A3D4A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF1A5060)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: const Color(0xFFFEFFFE),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            fontSize: 14,
            color: const Color(0xFF4A7A85),
          ),
          prefixIcon: Icon(icon, color: const Color(0xFF1B998B), size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}
