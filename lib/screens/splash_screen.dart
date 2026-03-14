import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/wallet_provider.dart';
import 'home_screen.dart';
import 'connect_screen.dart';
import 'pin_screen.dart';
import 'biometric_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _glow =
        Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
    _init();
  }

  Future<void> _init() async {
    await context.read<WalletProvider>().initialize();
    if (!mounted) return;

    final prefs       = await SharedPreferences.getInstance();
    final hasPin      = prefs.getString('morpheus_pin') != null;
    final useBiometric = prefs.getBool('morpheus_biometric') ?? false;
    final isConnected = context.read<WalletProvider>().isConnected;

    Widget Function() destination =
        () => isConnected ? const HomeScreen() : const ConnectScreen();

    // Check whether the device actually supports biometrics
    bool biometricAvailable = false;
    if (useBiometric && hasPin) {
      try {
        final localAuth = LocalAuthentication();
        biometricAvailable = await localAuth.canCheckBiometrics ||
            await localAuth.isDeviceSupported();
      } catch (_) {}
    }

    if (!mounted) return;

    if (useBiometric && hasPin && biometricAvailable) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BiometricScreen(nextScreen: destination),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PinScreen(
            mode: hasPin ? PinMode.enter : PinMode.create,
            nextScreen: destination,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0e0a),
      body: Stack(
        children: [
          CustomPaint(
            painter: _GridPainter(),
            child: const SizedBox.expand(),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _glow,
                  builder: (_, child) => Opacity(
                    opacity: _glow.value,
                    child: child,
                  ),
                  child: Image.asset(
                    'assets/icon/icon.png',
                    width: 180,
                    errorBuilder: (_, __, ___) =>
                        const Icon(
                      Icons.bolt,
                      color: Color(0xFF00ff41),
                      size: 80,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'MORPHEUS',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00ff41),
                    letterSpacing: 6,
                    shadows: [
                      Shadow(
                          color: Color(0xFF00ff41),
                          blurRadius: 10),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'lightning network wallet',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: Color(0xFFF7931A),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 32),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Color(0xFFF7931A),
                    strokeWidth: 2,
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

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00ff41).withOpacity(0.04)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 20) {
      canvas.drawLine(
          Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 20) {
      canvas.drawLine(
          Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
