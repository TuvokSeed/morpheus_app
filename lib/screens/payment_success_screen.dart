import 'dart:math';
import 'package:flutter/material.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final int? amountSats;
  final String memo;
  final bool isSend;

  const PaymentSuccessScreen({
    super.key,
    this.amountSats,
    required this.memo,
    this.isSend = false,
  });

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen>
    with TickerProviderStateMixin {
  late AnimationController _ringController;
  late AnimationController _textController;
  late AnimationController _particleController;
  late AnimationController _pulseController;

  late Animation<double> _ring1;
  late Animation<double> _ring2;
  late Animation<double> _ring3;
  late Animation<double> _textFade;
  late Animation<double> _textSlide;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _ring1 = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ringController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _ring2 = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ringController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );
    _ring3 = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ringController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _textFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );
    _textSlide = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    _pulse = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Sequence the animations
    _ringController.forward().then((_) {
      _textController.forward();
      _particleController.forward();
    });
  }

  @override
  void dispose() {
    _ringController.dispose();
    _textController.dispose();
    _particleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0e0a),
      body: Stack(
        children: [
          // Grid background
          CustomPaint(
            painter: _GridPainter(),
            child: const SizedBox.expand(),
          ),

          // Particles
          AnimatedBuilder(
            animation: _particleController,
            builder: (_, __) => CustomPaint(
              painter: _ParticlePainter(progress: _particleController.value),
              child: const SizedBox.expand(),
            ),
          ),

          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ─── Ripple rings + bolt icon ──────────────────
                SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Ring 3 — outermost
                      AnimatedBuilder(
                        animation: _ring3,
                        builder: (_, __) => _RippleRing(
                          progress: _ring3.value,
                          maxRadius: 110,
                          color: const Color(0xFF00ff41),
                          strokeWidth: 1,
                        ),
                      ),
                      // Ring 2
                      AnimatedBuilder(
                        animation: _ring2,
                        builder: (_, __) => _RippleRing(
                          progress: _ring2.value,
                          maxRadius: 85,
                          color: const Color(0xFF00ff41),
                          strokeWidth: 1.5,
                        ),
                      ),
                      // Ring 1 — innermost
                      AnimatedBuilder(
                        animation: _ring1,
                        builder: (_, __) => _RippleRing(
                          progress: _ring1.value,
                          maxRadius: 60,
                          color: const Color(0xFFF7931A),
                          strokeWidth: 2,
                        ),
                      ),
                      // Center bolt circle
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, child) => Transform.scale(
                          scale: _pulse.value,
                          child: child,
                        ),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF00ff41).withOpacity(0.1),
                            border: Border.all(
                              color: const Color(0xFF00ff41),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00ff41).withOpacity(0.4),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.bolt,
                              color: Color(0xFF00ff41),
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ─── Text content ──────────────────────────────
                AnimatedBuilder(
                  animation: _textController,
                  builder: (_, child) => Opacity(
                    opacity: _textFade.value,
                    child: Transform.translate(
                      offset: Offset(0, _textSlide.value),
                      child: child,
                    ),
                  ),
                  child: Column(
                    children: [
                      // SUCCESS label
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF00ff41),
                            width: 1,
                          ),
                          color: const Color(0xFF00ff41).withOpacity(0.08),
                        ),
                        child: Text(
                          widget.isSend ? '> PAYMENT SENT' : '> PAYMENT RECEIVED',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00ff41),
                            letterSpacing: 3,
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Amount
                      if (widget.amountSats != null && widget.amountSats! > 0)
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFF00ff41), Color(0xFFF7931A)],
                          ).createShader(bounds),
                          child: Text(
                            '${widget.isSend ? '-' : '+'}${widget.amountSats} sats',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 44,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                        ),

                      const SizedBox(height: 8),

                      // Memo if present
                      if (widget.memo.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.memo,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: Color(0xFF00cc33),
                            letterSpacing: 1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Terminal line
                      const _BlinkingCursor(),

                      const SizedBox(height: 40),

                      // Dismiss button
                      SizedBox(
                        width: 220,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF00ff41).withOpacity(0.1),
                            side: const BorderSide(
                              color: Color(0xFF00ff41),
                              width: 2,
                            ),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                          child: const Text(
                            '[ CLOSE ]',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00ff41),
                              letterSpacing: 3,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
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

// ─── Ripple ring painter ────────────────────────────────────
class _RippleRing extends StatelessWidget {
  final double progress;
  final double maxRadius;
  final Color color;
  final double strokeWidth;

  const _RippleRing({
    required this.progress,
    required this.maxRadius,
    required this.color,
    required this.strokeWidth,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RingPainter(
        progress: progress,
        maxRadius: maxRadius,
        color: color,
        strokeWidth: strokeWidth,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double maxRadius;
  final Color color;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.maxRadius,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = maxRadius * progress;
    final opacity = (1 - progress).clamp(0.0, 1.0);

    final paint = Paint()
      ..color = color.withOpacity(opacity * 0.8)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress;
}

// ─── Particle painter ───────────────────────────────────────
class _ParticlePainter extends CustomPainter {
  final double progress;
  final List<_Particle> _particles;

  _ParticlePainter({required this.progress})
      : _particles = _generateParticles();

  static List<_Particle> _generateParticles() {
    final rng = Random(42);
    return List.generate(30, (i) {
      final angle = (i / 30) * 2 * pi + rng.nextDouble() * 0.4;
      final speed = 80 + rng.nextDouble() * 120;
      final size = 2 + rng.nextDouble() * 3;
      final isOrange = rng.nextBool();
      return _Particle(
        angle: angle,
        speed: speed,
        size: size,
        color: isOrange ? const Color(0xFFF7931A) : const Color(0xFF00ff41),
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (final p in _particles) {
      final dist = p.speed * progress;
      final x = center.dx + cos(p.angle) * dist;
      final y = center.dy + sin(p.angle) * dist;
      final opacity = (1 - progress).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = p.color.withOpacity(opacity * 0.9)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), p.size * (1 - progress * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}

class _Particle {
  final double angle;
  final double speed;
  final double size;
  final Color color;

  _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
  });
}

// ─── Blinking cursor ────────────────────────────────────────
class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Text(
        '> FUNDS ROUTED_${_ctrl.value > 0.5 ? '█' : ' '}',
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: Color(0xFF00cc33),
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// ─── Grid background ────────────────────────────────────────
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
