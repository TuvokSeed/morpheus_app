import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'pin_screen.dart';

class BiometricScreen extends StatefulWidget {
  /// Called after successful auth to build the destination screen.
  final Widget Function() nextScreen;

  const BiometricScreen({super.key, required this.nextScreen});

  @override
  State<BiometricScreen> createState() => _BiometricScreenState();
}

class _BiometricScreenState extends State<BiometricScreen>
    with SingleTickerProviderStateMixin {
  static const _maxAttempts = 3;

  final _auth = LocalAuthentication();
  int _attempts = 0;
  bool _authenticating = false;
  String? _message;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    // Trigger auth automatically on open
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryAuth());
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _tryAuth() async {
    if (_authenticating) return;
    setState(() {
      _authenticating = true;
      _message = null;
    });

    bool success = false;
    try {
      success = await _auth.authenticate(
        localizedReason: 'Identify yourself to open Morpheus',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      success = false;
    }

    if (!mounted) return;
    setState(() => _authenticating = false);

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => widget.nextScreen()),
      );
      return;
    }

    // Failed attempt
    final newAttempts = _attempts + 1;
    setState(() => _attempts = newAttempts);

    if (newAttempts >= _maxAttempts) {
      // Fall back to PIN
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PinScreen(
            mode: PinMode.enter,
            nextScreen: widget.nextScreen,
          ),
        ),
      );
    } else {
      setState(() => _message =
          'FAILED — ${_maxAttempts - newAttempts} ATTEMPT${_maxAttempts - newAttempts == 1 ? '' : 'S'} LEFT');
    }
  }

  void _fallbackToPin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PinScreen(
          mode: PinMode.enter,
          nextScreen: widget.nextScreen,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attemptsLeft = _maxAttempts - _attempts;

    return Scaffold(
      backgroundColor: const Color(0xFF0a0e0a),
      body: Stack(
        children: [
          CustomPaint(painter: _GridPainter(), child: const SizedBox.expand()),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Fingerprint icon with pulse
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, child) => Transform.scale(
                        scale: _authenticating ? _pulse.value : 1.0,
                        child: child,
                      ),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF00ff41).withOpacity(0.08),
                          border: Border.all(
                            color: _message != null
                                ? const Color(0xFFff4444)
                                : const Color(0xFF00ff41),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_message != null
                                      ? const Color(0xFFff4444)
                                      : const Color(0xFF00ff41))
                                  .withOpacity(0.3),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.fingerprint,
                            size: 52,
                            color: Color(0xFF00ff41),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    const Text(
                      'FINGERPRINT AUTH',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00ff41),
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _authenticating
                          ? '> scanning...'
                          : '> touch sensor to authenticate',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Color(0xFF00cc33),
                        letterSpacing: 1,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Attempt dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_maxAttempts, (i) {
                        final used = i < _attempts;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: used
                                ? const Color(0xFFff4444)
                                : Colors.transparent,
                            border: Border.all(
                              color: used
                                  ? const Color(0xFFff4444)
                                  : const Color(0xFF00ff41).withOpacity(0.4),
                              width: 2,
                            ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 16),

                    // Error message
                    SizedBox(
                      height: 18,
                      child: _message != null
                          ? Text(
                              _message!,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: Color(0xFFff4444),
                                letterSpacing: 1,
                              ),
                            )
                          : null,
                    ),

                    const SizedBox(height: 32),

                    // Retry button
                    if (!_authenticating && _attempts > 0 && _attempts < _maxAttempts)
                      SizedBox(
                        width: 220,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _tryAuth,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF00ff41).withOpacity(0.1),
                            side: const BorderSide(
                                color: Color(0xFF00ff41), width: 2),
                            shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero),
                          ),
                          child: const Text(
                            '[ TRY AGAIN ]',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00ff41),
                              letterSpacing: 2,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 12),

                    // Use PIN instead
                    TextButton(
                      onPressed: _fallbackToPin,
                      child: const Text(
                        'USE PIN INSTEAD',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Color(0xFF005511),
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
      ..color = const Color(0xFF00ff41).withOpacity(0.03)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
