import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  static const _pink = Color(0xFFE91E63);
  static const _softPink = Color(0xFFFFF5F8);
  static const _textColor = Color(0xFF34212A);
  static const _cardColor = Colors.white;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(
    String label,
    IconData icon, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF806A74)),
      prefixIcon: Icon(icon, color: _pink),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFFFFAFC),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _pink.withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _pink, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : _pink,
      ),
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    setState(() => _isLoading = true);
    try {
      final emailExists = await AppDatabase.instance.isEmailRegistered(email);
      if (!mounted) return;
      if (emailExists) {
        _showMessage(
          'Email sudah terdaftar! Gunakan email lain.',
          isError: true,
        );
        return;
      }

      await AppDatabase.instance.registerUser(
        name: name,
        email: email,
        password: password,
      );
      if (!mounted) return;
      _showMessage('Registrasi berhasil! Silakan login.');
      Navigator.of(context).pop();
    } on DatabaseException catch (error) {
      if (!mounted) return;
      final message = error.isUniqueConstraintError()
          ? 'Email sudah terdaftar! Gunakan email lain.'
          : 'Registrasi gagal: $error';
      _showMessage(message, isError: true);
    } catch (error) {
      if (!mounted) return;
      _showMessage('Registrasi gagal: $error', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _softPink,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _pink),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Register',
          style: TextStyle(color: _textColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  Card(
                    color: _cardColor,
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: _pink.withValues(alpha: 0.25),
                        width: 1.2,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Create Account',
                              style: TextStyle(
                                color: _textColor,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Ayo Join ShoppingHub',
                              style: TextStyle(color: _pink, fontSize: 14),
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _nameController,
                              keyboardType: TextInputType.name,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(color: _textColor),
                              decoration: _inputDecoration(
                                'Full Name',
                                Icons.person_outline,
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Nama wajib diisi.'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(color: _textColor),
                              decoration: _inputDecoration(
                                'Email',
                                Icons.email_outlined,
                              ),
                              validator: (value) =>
                                  value == null || !_isValidEmail(value.trim())
                                  ? 'Format email tidak valid.'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(
                                color: Color.fromARGB(255, 30, 20, 20),
                              ),
                              decoration: _inputDecoration(
                                'Password',
                                Icons.lock_outline,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: _pink,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.length < 6
                                  ? 'Password minimal 6 karakter.'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              style: const TextStyle(color: _textColor),
                              decoration: _inputDecoration(
                                'Confirm Password',
                                Icons.lock_reset,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: _pink,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscureConfirmPassword =
                                        !_obscureConfirmPassword,
                                  ),
                                ),
                              ),
                              validator: (value) =>
                                  value != _passwordController.text
                                  ? 'Konfirmasi password tidak cocok.'
                                  : null,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _register,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _pink,
                                  disabledBackgroundColor: _pink.withValues(
                                    alpha: 0.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 4,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Color.fromARGB(255, 30, 20, 20),
                                              ),
                                        ),
                                      )
                                    : const Text(
                                        'Register',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(
                          color: Color(0xFF806A74),
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            color: _pink,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
