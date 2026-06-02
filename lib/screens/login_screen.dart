import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLogin = true; // Toggle between Login and Register
  bool _obscurePassword = true;
  String? _errorMessage;
  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

  void _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields');
      return;
    }

    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters');
      return;
    }

    setState(() => _errorMessage = null);

    try {
      if (_isLogin) {
        await _authService.signIn(email: email, password: password);
      } else {
        await _authService.signUp(email: email, password: password);
        setState(() {
          _isLogin = true;
          _passwordController.clear();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Account created! Please sign in.'),
            backgroundColor: AppColors.accentGreen,
            behavior: SnackBarBehavior.floating,
          ));
        }
        return;
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'user-not-found':
            _errorMessage = 'No account found with this email';
            break;
          case 'wrong-password':
          case 'invalid-credential':
            _errorMessage = 'Incorrect password';
            break;
          case 'email-already-in-use':
            _errorMessage = 'An account already exists with this email';
            break;
          case 'invalid-email':
            _errorMessage = 'Invalid email address';
            break;
          default:
            _errorMessage = e.message ?? 'Authentication failed';
        }
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.5, -0.6),
            radius: 1.5,
            colors: [
              Color(0xFF161B30),
              AppColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16.0),
              child: FadeTransition(
                opacity: _fadeCtrl,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Glowing Icon Logo
                    Center(
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: AppColors.accentRed.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.accentRed.withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.shield_rounded,
                          size: 42,
                          color: AppColors.accentRed,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'SIREN',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 6,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isLogin ? 'Emergency Alert & Safety System' : 'Create your credentials to secure your circle',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Inputs Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Column(
                        children: [
                          _buildFocusInput(
                            controller: _emailController,
                            label: 'Email Address',
                            hint: 'name@domain.com',
                            icon: Icons.email_rounded,
                            type: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          _buildFocusInput(
                            controller: _passwordController,
                            label: 'Password',
                            hint: '••••••••',
                            icon: Icons.lock_rounded,
                            type: TextInputType.visiblePassword,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Error Message
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.accentRed,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Submit Button
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _authService.isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _authService.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.black,
                                ),
                              )
                            : Text(
                                _isLogin ? 'Sign In' : 'Create Account',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Toggle Login/Register
                    TextButton(
                      onPressed: () => setState(() {
                        _isLogin = !_isLogin;
                        _errorMessage = null;
                      }),
                      child: Text.rich(
                        TextSpan(
                          text: _isLogin ? "Don't have an account? " : 'Already have an account? ',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          children: [
                            TextSpan(
                              text: _isLogin ? 'Sign Up' : 'Sign In',
                              style: const TextStyle(
                                color: AppColors.accentRed,
                                fontWeight: FontWeight.w800,
                              ),
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
        ),
      ),
    );
  }

  Widget _buildFocusInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required TextInputType type,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Focus(
      onFocusChange: (hasFocus) {
        setState(() {}); // Force update for glow highlights
      },
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasFocus ? AppColors.accentRed : AppColors.surfaceBorder,
                width: hasFocus ? 1.5 : 1.0,
              ),
              boxShadow: hasFocus
                  ? [
                      BoxShadow(
                        color: AppColors.accentRed.withValues(alpha: 0.15),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ]
                  : [],
            ),
            child: TextField(
              controller: controller,
              keyboardType: type,
              obscureText: obscureText,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                prefixIcon: Icon(
                  icon,
                  color: hasFocus ? AppColors.accentRed : AppColors.textSecondary,
                  size: 20,
                ),
                suffixIcon: suffixIcon,
                labelText: label,
                labelStyle: TextStyle(
                  color: hasFocus ? AppColors.accentRed : AppColors.textSecondary,
                  fontSize: 13,
                ),
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.white10, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          );
        },
      ),
    );
  }
}
