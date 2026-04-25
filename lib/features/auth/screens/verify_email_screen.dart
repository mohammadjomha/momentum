import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  Timer? _pollTimer;
  Timer? _debounceTimer;
  bool _resendDisabled = false;
  int _debounceSecondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _onMount();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _onMount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Check skipEmailVerification flag from Firestore.
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.data()?['skipEmailVerification'] == true) {
        if (mounted) context.go('/home');
        return;
      }
    } catch (_) {}

    // Check if already verified before showing the screen.
    await FirebaseAuth.instance.currentUser?.reload();
    final refreshed = FirebaseAuth.instance.currentUser;
    if (refreshed?.emailVerified == true) {
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      if (mounted) context.go('/home');
      return;
    }

    _startPolling();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      await FirebaseAuth.instance.currentUser?.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      if (refreshed?.emailVerified == true) {
        _pollTimer?.cancel();
        await FirebaseAuth.instance.currentUser?.getIdToken(true);
        if (mounted) context.go('/home');
      }
    });
  }

  Future<void> _resend() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await user.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: ${e.toString()}')),
        );
      }
    }
    _startDebounce();
  }

  void _startDebounce() {
    setState(() {
      _resendDisabled = true;
      _debounceSecondsLeft = 30;
    });
    _debounceTimer?.cancel();
    _debounceTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _debounceSecondsLeft--);
      if (_debounceSecondsLeft <= 0) {
        t.cancel();
        setState(() => _resendDisabled = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppTheme.accent.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_outlined,
                    color: AppTheme.accent,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Verify your email',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'We sent a verification link to $email. Open it to continue.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _resendDisabled ? null : _resend,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      disabledBackgroundColor:
                          AppTheme.accent.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _resendDisabled
                          ? 'Resend Email ($_debounceSecondsLeft s)'
                          : 'Resend Email',
                      style: const TextStyle(
                        color: AppTheme.background,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  child: const Text(
                    'Sign out',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
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