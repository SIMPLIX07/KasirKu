import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'business_name_page.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _registerWithEmail() async {
    final fullName = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (fullName.isEmpty || email.isEmpty || password.isEmpty) {
      _showMessage('Nama, email, dan kata sandi wajib diisi.');
      return;
    }

    if (password.length < 6) {
      _showMessage('Kata sandi minimal 6 karakter.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      await credential.user?.updateDisplayName(fullName);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const BusinessNamePage()),
      );
    } on FirebaseAuthException catch (e) {
      _showMessage(_friendlyError(e));
    } catch (_) {
      _showMessage('Gagal membuat akun. Coba lagi.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _registerWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const BusinessNamePage()),
      );
    } on FirebaseAuthException catch (e) {
      _showMessage(_friendlyError(e));
    } catch (_) {
      _showMessage('Daftar dengan Google gagal.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _friendlyError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'email-already-in-use':
        return 'Email sudah terdaftar.';
      case 'weak-password':
        return 'Kata sandi terlalu lemah.';
      case 'operation-not-allowed':
        return 'Metode pendaftaran belum diaktifkan di Firebase.';
      case 'network-request-failed':
        return 'Jaringan bermasalah. Periksa koneksi internet.';
      default:
        return error.message ?? 'Pendaftaran gagal.';
    }
  }

  InputDecoration _inputDecoration(
    String hintText, {
    required double hintSize,
    required double radius,
    required double verticalPadding,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: const Color(0xFFA2AAA7), fontSize: hintSize),
      filled: true,
      fillColor: const Color(0xFFF1F4F3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide.none,
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: 18,
        vertical: verticalPadding,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFF3F5F4);
    const cardColor = Color(0xFFF8FAF8);
    const textMain = Color(0xFF263230);
    const textSecondary = Color(0xFF6B7573);
    const primary = Color(0xFF126C55);
    const lineColor = Color(0xFFD9DFDC);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  const SizedBox(width: 48),
                  const Spacer(),
                  const Text(
                    'KASIRKU',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 10,
                      color: textMain,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scale = (constraints.maxHeight / 760).clamp(0.78, 1.0);
                  double s(num value) => value * scale;

                  return Padding(
                    padding: EdgeInsets.fromLTRB(s(18), s(10), s(18), s(8)),
                    child: Container(
                      padding: EdgeInsets.fromLTRB(s(20), s(24), s(20), s(10)),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(s(26)),
                        border: Border.all(color: const Color(0xFFE7ECEA)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Buat Akun Baru',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: s(26),
                              fontWeight: FontWeight.w800,
                              color: textMain,
                              height: 1.05,
                            ),
                          ),
                          SizedBox(height: s(8)),
                          Text(
                            'LENGKAPI DETAIL ANDA',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: s(12.5),
                              letterSpacing: s(3.2),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: s(18)),
                          Text(
                            'NAMA LENGKAP',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: s(11.5),
                              letterSpacing: s(2.3),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: s(8)),
                          TextField(
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            decoration: _inputDecoration(
                              'Masukkan nama lengkap',
                              hintSize: s(13),
                              radius: s(14),
                              verticalPadding: s(12),
                            ),
                            style: TextStyle(fontSize: s(16), color: textMain),
                          ),
                          SizedBox(height: s(14)),
                          Text(
                            'EMAIL',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: s(11.5),
                              letterSpacing: s(2.3),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: s(8)),
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: _inputDecoration(
                              'nama@email.com',
                              hintSize: s(13),
                              radius: s(14),
                              verticalPadding: s(12),
                            ),
                            style: TextStyle(fontSize: s(16), color: textMain),
                          ),
                          SizedBox(height: s(14)),
                          Text(
                            'KATA SANDI',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: s(11.5),
                              letterSpacing: s(2.3),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: s(8)),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            decoration: _inputDecoration(
                              '........',
                              hintSize: s(13),
                              radius: s(14),
                              verticalPadding: s(12),
                            ),
                            style: TextStyle(fontSize: s(16), color: textMain),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _registerWithEmail,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                elevation: 8,
                                shadowColor: primary.withValues(alpha: 0.25),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(s(14)),
                                ),
                                padding: EdgeInsets.symmetric(vertical: s(18)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Daftar Sekarang',
                                      style: TextStyle(
                                        fontSize: s(17),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                          SizedBox(height: s(50)),
                          Row(
                            children: [
                              Expanded(
                                child: Container(height: 1, color: lineColor),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: s(16),
                                ),
                                child: Text(
                                  'ATAU',
                                  style: TextStyle(
                                    color: const Color(0xFF9DA5A2),
                                    fontSize: s(11.5),
                                    letterSpacing: s(2),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(height: 1, color: lineColor),
                              ),
                            ],
                          ),
                          const SizedBox(height: 50),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _isLoading
                                  ? null
                                  : _registerWithGoogle,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFFD3DAD7),
                                ),
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(s(14)),
                                ),
                                padding: EdgeInsets.symmetric(vertical: s(13)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _GoogleGIcon(size: s(23)),
                                  SizedBox(width: s(10)),
                                  Text(
                                    'Daftar dengan Google',
                                    style: TextStyle(
                                      color: textMain,
                                      fontSize: s(16),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: s(12)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Sudah punya akun? ',
                                style: TextStyle(
                                  fontSize: s(14),
                                  color: textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const LoginPage(),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: primary,
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Masuk',
                                  style: TextStyle(
                                    fontSize: s(14),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        color: const Color(0xFFF7F7F7),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: _BottomNavItem(
                  icon: Icons.login,
                  label: 'LOGIN',
                  color: const Color(0xFFA7A2A2),
                  onTap: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => const LoginPage(),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: _BottomNavItem(
                  icon: Icons.person_add_alt,
                  label: 'REGISTER',
                  color: primary,
                  onTap: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleGIcon extends StatelessWidget {
  const _GoogleGIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) {
          return const SweepGradient(
            colors: [
              Color(0xFF4285F4),
              Color(0xFF34A853),
              Color(0xFFFBBC05),
              Color(0xFFEA4335),
              Color(0xFF4285F4),
            ],
            stops: [0.0, 0.32, 0.55, 0.8, 1.0],
          ).createShader(bounds);
        },
        child: Text(
          'G',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: size * 0.86,
            height: 1,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
