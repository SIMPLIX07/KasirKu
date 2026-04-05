import 'dart:async';

import 'package:flutter/material.dart';

import 'auth_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _redirectTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _redirectTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const AuthGate()),
      );
    });
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF126C55);
    const textMain = Color(0xFF263330);
    const textSubtle = Color(0xFF6B7774);

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -110,
            left: -80,
            child: _BlurOrb(color: const Color(0xFFE8EEEA), size: 260),
          ),
          Positioned(
            bottom: 150,
            right: -90,
            child: _BlurOrb(color: primary.withValues(alpha: 0.09), size: 280),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.point_of_sale_rounded,
                            size: 58,
                            color: primary.withValues(alpha: 0.9),
                          ),
                          const SizedBox(height: 72),
                          const Text(
                            'KASIRKU',
                            style: TextStyle(
                              fontSize: 46,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 15,
                              color: textMain,
                              height: 0.9,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Aplikasi Kasir UMKM',
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w300,
                                letterSpacing: 3,
                                color: textSubtle,
                              ),
                            ),
                          ),
                          const SizedBox(height: 70),
                          _LoadingDots(controller: _controller, color: primary),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Container(
                    height: 132,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0x26AEB7B4), Color(0x1F8A9390)],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.receipt_long_rounded,
                        size: 54,
                        color: Colors.white.withValues(alpha: 0.32),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text(
                    'VER. 2.4.0 • PREMIUM MERCHANT EXPERIENCE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFB8BEBB),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 3,
                    ),
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

class _LoadingDots extends StatelessWidget {
  const _LoadingDots({required this.controller, required this.color});

  final AnimationController controller;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final value = controller.value;
        final dot1 =
            0.24 + (0.5 * (1 - (value - 0.15).abs() * 1.7).clamp(0, 1));
        final dot2 = 0.24 + (0.5 * (1 - (value - 0.5).abs() * 1.7).clamp(0, 1));
        final dot3 =
            0.24 + (0.5 * (1 - (value - 0.85).abs() * 1.7).clamp(0, 1));

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Dot(opacity: dot1, color: color),
            const SizedBox(width: 12),
            _Dot(opacity: dot2, color: color),
            const SizedBox(width: 12),
            _Dot(opacity: dot3, color: color),
          ],
        );
      },
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.opacity, required this.color});

  final double opacity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: color.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _BlurOrb extends StatelessWidget {
  const _BlurOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
