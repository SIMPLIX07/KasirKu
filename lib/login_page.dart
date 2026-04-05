import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_gate.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
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

  Future<void> _signInWithEmailPassword() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Email dan password wajib diisi.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const AuthGate()),
      );
    } on FirebaseAuthException catch (e) {
      _showMessage(_friendlyError(e));
    } catch (_) {
      _showMessage('Terjadi kesalahan, coba lagi.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
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
        MaterialPageRoute<void>(builder: (_) => const AuthGate()),
      );
    } on FirebaseAuthException catch (e) {
      _showMessage(_friendlyError(e));
    } catch (_) {
      _showMessage('Gagal login Google. Cek konfigurasi Firebase.');
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
      case 'user-not-found':
        return 'Akun tidak ditemukan.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email atau password salah.';
      case 'user-disabled':
        return 'Akun ini dinonaktifkan.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi nanti.';
      case 'network-request-failed':
        return 'Jaringan bermasalah. Periksa koneksi internet.';
      case 'operation-not-allowed':
        return 'Metode login belum diaktifkan di Firebase.';
      default:
        return error.message ?? 'Autentikasi gagal.';
    }
  }

  Future<void> _sendPasswordResetEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('Isi email terlebih dulu untuk reset kata sandi.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showMessage('Link reset kata sandi sudah dikirim ke email Anda.');
    } on FirebaseAuthException catch (e) {
      _showMessage(_friendlyError(e));
    } catch (_) {
      _showMessage('Gagal mengirim email reset kata sandi.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFF1F3F2);
    const textMain = Color(0xFF25302E);
    const textSecondary = Color(0xFF6C7573);
    const lineColor = Color(0xFFA5AFAC);
    const primary = Color(0xFF126C55);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = (constraints.maxHeight / 780).clamp(0.9, 1.06);
            double s(num value) => value * scale;

            return Padding(
              padding: EdgeInsets.fromLTRB(s(22), s(8), s(22), s(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: s(6)),
                  Center(
                    child: Text(
                      'KASIRKU',
                      style: TextStyle(
                        fontSize: s(22),
                        fontWeight: FontWeight.w600,
                        letterSpacing: s(8),
                        color: textMain,
                      ),
                    ),
                  ),
                  SizedBox(height: s(34)),
                  Text(
                    'MERCHANT PORTAL',
                    style: TextStyle(
                      color: primary,
                      letterSpacing: s(4.2),
                      fontSize: s(12),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: s(15)),
                  Text(
                    'Welcome',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: s(58),
                      height: 0.95,
                      color: textMain,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  SizedBox(height: s(10)),
                  Text(
                    'Masuk untuk mengelola usaha Anda hari ini.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: s(18),
                      color: textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(height: s(40)),
                  Divider(
                    color: lineColor.withValues(alpha: 0.45),
                    thickness: 1,
                    height: s(1),
                  ),
                  SizedBox(height: s(14)),
                  Text(
                    'EMAIL ADDRESS',
                    style: TextStyle(
                      fontSize: s(12),
                      letterSpacing: s(2.4),
                      color: textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    maxLines: 1,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'nama@domain.com',
                      hintStyle: TextStyle(
                        color: const Color(0xFFB9C0BE),
                        fontSize: s(15),
                        fontWeight: FontWeight.w500,
                      ),
                      border: const UnderlineInputBorder(
                        borderSide: BorderSide(color: lineColor),
                      ),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: lineColor),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: primary, width: 1.4),
                      ),
                      contentPadding: EdgeInsets.only(
                        top: s(12),
                        bottom: s(10),
                      ),
                    ),
                    style: TextStyle(
                      fontSize: s(16),
                      color: textMain,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: s(18)),
                  Text(
                    'PASSWORD',
                    style: TextStyle(
                      fontSize: s(12),
                      letterSpacing: s(2.4),
                      color: textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    maxLines: 1,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '........',
                      hintStyle: TextStyle(
                        color: const Color(0xFFB9C0BE),
                        fontSize: s(15),
                        letterSpacing: s(1.4),
                        fontWeight: FontWeight.w500,
                      ),
                      border: const UnderlineInputBorder(
                        borderSide: BorderSide(color: lineColor),
                      ),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: lineColor),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: primary, width: 1.4),
                      ),
                      contentPadding: EdgeInsets.only(
                        top: s(12),
                        bottom: s(10),
                      ),
                    ),
                    style: TextStyle(
                      fontSize: s(16),
                      color: textMain,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: s(4)),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _sendPasswordResetEmail,
                      style: TextButton.styleFrom(
                        foregroundColor: textSecondary,
                        textStyle: TextStyle(fontSize: s(10.5)),
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('LUPA KATA SANDI?'),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signInWithEmailPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        elevation: 8,
                        shadowColor: primary.withValues(alpha: 0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(s(16)),
                        ),
                        padding: EdgeInsets.symmetric(vertical: s(20)),
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
                              'Masuk',
                              style: TextStyle(
                                fontSize: s(20),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: s(50)),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          color: lineColor.withValues(alpha: 0.3),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: s(16)),
                        child: Text(
                          'ATAU',
                          style: TextStyle(
                            fontSize: s(12),
                            letterSpacing: s(2),
                            color: const Color(0xFF9FA6A4),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: lineColor.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 50),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: lineColor.withValues(alpha: 0.35),
                        ),
                        backgroundColor: Colors.white.withValues(alpha: 0.62),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(s(14)),
                        ),
                        padding: EdgeInsets.symmetric(vertical: s(16)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: s(30),
                            height: s(30),
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
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
                                style: TextStyle(
                                  fontSize: s(19),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: s(12)),
                          Text(
                            'Masuk dengan Google',
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
                  SizedBox(height: s(18)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Belum memiliki akun? ',
                        style: TextStyle(
                          fontSize: s(12.5),
                          color: textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute<void>(
                              builder: (_) => const RegisterPage(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: primary,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Daftar di sini',
                          style: TextStyle(
                            fontSize: s(12.5),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
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
                  color: primary,
                ),
              ),
              Expanded(
                child: _BottomNavItem(
                  icon: Icons.person_add_alt,
                  label: 'REGISTER',
                  color: Color(0xFFA7A2A2),
                  onTap: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => const RegisterPage(),
                      ),
                    );
                  },
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
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
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
