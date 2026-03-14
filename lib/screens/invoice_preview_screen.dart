import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import 'payment_success_screen.dart';

/// Decode the sats amount from a BOLT11 invoice human-readable prefix.
/// Returns null if no amount is encoded (zero-amount invoice).
int? decodeBolt11Sats(String invoice) {
  final raw = invoice.toLowerCase().trim();
  final stripped = raw.startsWith('lightning:') ? raw.substring(10) : raw;

  // lnbc / lntb / lnbcrt / lnsb  +  optional amount digits + multiplier + '1'
  final regex = RegExp(r'^ln(?:bc|tb|bcrt|sb)(\d+)([munp])?1');
  final match = regex.firstMatch(stripped);
  if (match == null) return null;

  final amountStr = match.group(1);
  if (amountStr == null || amountStr.isEmpty) return null;

  final amount = int.tryParse(amountStr);
  if (amount == null || amount == 0) return null;

  // Convert amount to millisatoshis  (1 BTC = 100 000 000 000 msats)
  final int millisats;
  switch (match.group(2)) {
    case 'm':
      millisats = amount * 100000000; // milli-BTC
    case 'u':
      millisats = amount * 100000; // micro-BTC
    case 'n':
      millisats = amount * 100; // nano-BTC
    case 'p':
      millisats = amount ~/ 10; // pico-BTC
    default:
      millisats = amount * 100000000000; // whole BTC
  }

  return millisats ~/ 1000;
}

class InvoicePreviewScreen extends StatefulWidget {
  final String invoice;

  const InvoicePreviewScreen({super.key, required this.invoice});

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen>
    with SingleTickerProviderStateMixin {
  bool _paying = false;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmPay() async {
    setState(() => _paying = true);
    final provider = context.read<WalletProvider>();
    final balanceBefore = provider.balance;
    final error = await provider.payInvoice(widget.invoice);
    if (!mounted) return;
    setState(() => _paying = false);

    if (error == null) {
      final amountPaid = (balanceBefore - provider.balance).abs();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentSuccessScreen(
            isSend: true,
            amountSats: amountPaid > 0 ? amountPaid : decodeBolt11Sats(widget.invoice),
            memo: '',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0a0e0a),
          duration: const Duration(seconds: 5),
          content: Row(
            children: [
              const Text('✗ ',
                  style: TextStyle(color: Color(0xFFff4444), fontSize: 16)),
              Expanded(
                child: Text(
                  error,
                  style: const TextStyle(
                    color: Color(0xFFff4444),
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  String _truncateInvoice(String inv) {
    if (inv.length <= 32) return inv;
    return '${inv.substring(0, 20)}...${inv.substring(inv.length - 8)}';
  }

  @override
  Widget build(BuildContext context) {
    final sats = decodeBolt11Sats(widget.invoice);
    final isZeroAmount = sats == null || sats == 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0a0e0a),
      appBar: AppBar(title: const Text('INVOICE PREVIEW')),
      body: Stack(
        children: [
          CustomPaint(painter: _GridPainter(), child: const SizedBox.expand()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),

                  // Pulsing bolt icon
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, child) => Transform.scale(
                      scale: _pulse.value,
                      child: child,
                    ),
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF7931A).withOpacity(0.1),
                        border: Border.all(
                            color: const Color(0xFFF7931A), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF7931A).withOpacity(0.35),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.bolt, color: Color(0xFFF7931A), size: 44),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // "YOU ARE ABOUT TO PAY" label
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: const Color(0xFF00ff41), width: 1),
                      color: const Color(0xFF00ff41).withOpacity(0.06),
                    ),
                    child: const Text(
                      '> YOU ARE ABOUT TO PAY',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00ff41),
                        letterSpacing: 2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Amount display
                  if (!isZeroAmount)
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF00ff41), Color(0xFFF7931A)],
                      ).createShader(bounds),
                      child: Text(
                        '$sats sats',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    )
                  else
                    Column(
                      children: [
                        const Text(
                          'ZERO-AMOUNT INVOICE',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF7931A),
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'amount set by sender',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Color(0xFF00cc33),
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 32),

                  // Invoice string (truncated + copy)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '> INVOICE',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Color(0xFF00cc33),
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: widget.invoice));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Color(0xFF0a0e0a),
                          content: Text(
                            '✓ INVOICE COPIED',
                            style: TextStyle(
                              color: Color(0xFF00ff41),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: const Color(0xFF00ff41).withOpacity(0.25),
                            width: 1),
                        color: const Color(0xFF00ff41).withOpacity(0.04),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _truncateInvoice(widget.invoice),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: Color(0xFF00cc33),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.copy,
                              color: Color(0xFF00ff41), size: 16),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _paying ? null : _confirmPay,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFFF7931A).withOpacity(0.12),
                        side: const BorderSide(
                            color: Color(0xFFF7931A), width: 2),
                        shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero),
                      ),
                      child: _paying
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Color(0xFFF7931A),
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'CONFIRM & PAY',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFF7931A),
                                letterSpacing: 2,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Cancel button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: _paying
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text(
                        '[ CANCEL ]',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: Color(0xFF005511),
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          if (_paying) const _SendingOverlay(),
        ],
      ),
    );
  }
}

// ─── Full-screen sending overlay ───────────────────────────
class _SendingOverlay extends StatefulWidget {
  const _SendingOverlay();
  @override
  State<_SendingOverlay> createState() => _SendingOverlayState();
}

class _SendingOverlayState extends State<_SendingOverlay>
    with TickerProviderStateMixin {
  late AnimationController _spinController;
  late AnimationController _pulseController;
  late AnimationController _dotsController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _spinController.dispose();
    _pulseController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xE50a0e0a),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _spinController,
                    builder: (_, __) => Transform.rotate(
                      angle: _spinController.value * 2 * pi,
                      child: CustomPaint(
                        painter: _ArcPainter(),
                        size: const Size(120, 120),
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, child) => Transform.scale(
                      scale: 0.9 + _pulseController.value * 0.2,
                      child: child,
                    ),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF7931A).withOpacity(0.12),
                        border: Border.all(
                            color: const Color(0xFFF7931A), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF7931A).withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.bolt, color: Color(0xFFF7931A), size: 32),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'ROUTING PAYMENT',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00ff41),
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 12),
            AnimatedBuilder(
              animation: _dotsController,
              builder: (_, __) {
                final dots =
                    '.' * ((_dotsController.value * 4).floor() % 4);
                return Text(
                  '> BROADCASTING$dots',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Color(0xFF00cc33),
                    letterSpacing: 2,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final paint = Paint()
      ..color = const Color(0xFFF7931A)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      pi * 1.4,
      false,
      paint,
    );
    final paint2 = Paint()
      ..color = const Color(0xFF00ff41).withOpacity(0.3)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2 + pi * 1.4,
      pi * 0.6,
      false,
      paint2,
    );
  }

  @override
  bool shouldRepaint(_) => false;
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
