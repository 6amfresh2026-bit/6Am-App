import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:food_user_application/core/services/update_service.dart';

import '../../../auth/application/auth_controller.dart';
import '../../../auth/application/auth_state.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    UpdateService.checkForUpdate();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.bottom],
    );
    _timer = Timer(const Duration(milliseconds: 1500), _tryNavigate);
  }

  void _tryNavigate() {
    if (!mounted) return;
    final authState = ref.read(authControllerProvider);
    if (authState is AuthInitial || authState is AuthLoading) {
      // Re-check after 300ms if auth is still resolving
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 300), _tryNavigate);
      return;
    }
    if (authState is AuthAuthenticated) {
      context.go('/main');
    } else if (authState is AuthNeedsRegistration) {
      context.go('/register');
    } else if (authState is AuthPendingApproval) {
      context.go('/account-status');
    } else {
      context.go('/phone-login');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(
      authControllerProvider,
      (previous, next) => _tryNavigate(),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Image.asset(
          'assets/image/logo.png',
          width: 180.w,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
