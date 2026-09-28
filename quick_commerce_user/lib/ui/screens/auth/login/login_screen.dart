import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../navigation/route_paths.dart';
import 'login_provider.dart';
import 'login_state.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final sent = await ref.read(loginProvider.notifier).requestOtp();
    if (!sent || !mounted) return;

    final state = ref.read(loginProvider);
    context.push(
      RoutePaths.otp,
      extra: (phone: state.phone, debugOtp: state.debugOtp),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginProvider);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFEBF5EE),
      body: Stack(
        children: [
          // ── Layer 1: Top 3D Floating Produce Background ───────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.44,
            child: Container(
              color: const Color(0xFFEBF5EE),
              child: Image.asset(
                'assets/images/loginpage.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (context, error, stackTrace) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFDCFCE7), Color(0xFFF0FDF4)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Layer 2: White Card Sheet Overlapping Header ───────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  minHeight: size.height * 0.62,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(36),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, -6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Logo & Brand Header ("6am fresh")
                    _buildLogoHeader(),

                    const SizedBox(height: 4),

                    // Tagline: "Your Morning. Our Quality Fresh."
                    Text(
                      'Your Morning. Our Quality Fresh.',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF374151),
                        letterSpacing: 0.2,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // 2. Phone Input Field Container
                    _buildPhoneInput(state),

                    if (state.validationError != null || state.failure != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            state.validationError ?? state.failure!.message,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFFEF4444),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),

                    // 3. Continue Button with trailing arrow badge
                    _buildContinueButton(state),

                    const SizedBox(height: 20),

                    // 4. "New to 6am fresh? Sign Up" Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'New to 6am fresh? ',
                          style: GoogleFonts.inter(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF374151),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.push(RoutePaths.register),
                          child: Text(
                            'Sign Up',
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF157635),
                              decoration: TextDecoration.underline,
                              decorationColor: const Color(0xFF157635),
                              decorationThickness: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // 5. "OR" Horizontal Divider Line
                    Row(
                      children: [
                        const Expanded(
                          child: Divider(color: Color(0xFFE5E7EB), thickness: 1),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            'OR',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Divider(color: Color(0xFFE5E7EB), thickness: 1),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // 6. Login with Email / Facebook Action
                    GestureDetector(
                      onTap: () => context.push(RoutePaths.register),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.mail_outline_rounded,
                            color: Color(0xFF157635),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Login with Email / Facebook',
                            style: GoogleFonts.outfit(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF157635),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 6am fresh Dual-Tone Logo Widget with Leaf Accents
  Widget _buildLogoHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Green leaf decor on left
        Transform.rotate(
          angle: -0.4,
          child: const Icon(
            Icons.eco_rounded,
            color: Color(0xFF4ADE80),
            size: 16,
          ),
        ),
        const SizedBox(width: 4),

        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '6am ',
                style: GoogleFonts.outfit(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF2FB24D),
                  letterSpacing: -1.0,
                ),
              ),
              TextSpan(
                text: 'fresh',
                style: GoogleFonts.outfit(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF145D44),
                  letterSpacing: -1.0,
                ),
              ),
            ],
          ),
        ),

        // Leaf icon above "fresh"
        Transform.translate(
          offset: const Offset(-4, -12),
          child: Transform.rotate(
            angle: 0.3,
            child: const Icon(
              Icons.eco_rounded,
              color: Color(0xFF157635),
              size: 22,
            ),
          ),
        ),

        const SizedBox(width: 2),

        // Green leaf decor on right
        Transform.rotate(
          angle: 0.5,
          child: const Icon(
            Icons.eco_rounded,
            color: Color(0xFF4ADE80),
            size: 14,
          ),
        ),
      ],
    );
  }

  /// Mobile Number Input Pill Widget (+91 Prefix + Flag)
  Widget _buildPhoneInput(LoginState state) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFF6FAF7),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: (state.validationError != null || state.failure != null)
              ? const Color(0xFFEF4444)
              : const Color(0xFFCBE7D7),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          // India Flag Emoji
          const Text('🇮🇳', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),

          // Country Code (+91)
          Text(
            '+91',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(width: 10),

          // Vertical Divider Line
          Container(
            width: 1,
            height: 22,
            decoration: BoxDecoration(
              color: const Color(0xFFCBE7D7),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(width: 12),

          // Phone Number Input
          Expanded(
            child: TextField(
              controller: _controller,
              keyboardType: TextInputType.phone,
              autofocus: true,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1F2937),
                letterSpacing: 0.5,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              onChanged: ref.read(loginProvider.notifier).setPhone,
              onSubmitted: (_) => state.canSubmit ? _submit() : null,
              decoration: InputDecoration(
                hintText: 'Enter your mobile number',
                hintStyle: GoogleFonts.inter(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF9CA3AF),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Continue Button Widget with Green Gradient & Trailing Circular White Badge
  Widget _buildContinueButton(LoginState state) {
    final enabled = state.canSubmit;

    return GestureDetector(
      onTap: enabled ? _submit : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: enabled
                ? [const Color(0xFF2FB24D), const Color(0xFF137533)]
                : [const Color(0xFFA5DDB8), const Color(0xFF7CB88F)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: const Color(0xFF157635).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : const [],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            const SizedBox(width: 38), // Spacer balancing trailing badge width
            Expanded(
              child: Center(
                child: state.isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        'Continue',
                        style: GoogleFonts.outfit(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
              ),
            ),

            // Trailing White Circular Badge containing Green Arrow
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Color(0xFF137533),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

