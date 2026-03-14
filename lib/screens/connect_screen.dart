import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import 'home_screen.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _controller = TextEditingController();
  bool _scanning = false;
  String? _detailedError;

  Future<void> _connect() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _detailedError = null);

    final provider = context.read<WalletProvider>();
    final success =
        await provider.connect(_controller.text.trim());

    if (!mounted) return;
    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      setState(() => _detailedError = provider.error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0a0e0a),
          duration: const Duration(seconds: 6),
          content: Text(
            provider.error ?? 'CONNECTION FAILED',
            style: const TextStyle(
              color: Color(0xFFff4444),
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WalletProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFF0a0e0a),
      body: Stack(
        children: [
          const _GridBackground(),
          SafeArea(
            child: _scanning
                ? _buildScanner()
                : _buildForm(provider),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(WalletProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
          horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 32),

          // ─── Logo ──────────────────────────────────────────
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF7931A).withOpacity(0.08),
              border: Border.all(color: const Color(0xFFF7931A), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF7931A).withOpacity(0.3),
                  blurRadius: 32,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/icon/icon.png',
                width: 120,
                height: 120,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── Title ─────────────────────────────────────────
          const Text(
            'MORPHEUS',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFFF7931A),
              letterSpacing: 4,
              shadows: [
                Shadow(
                  color: Color(0xFFF7931A),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'LIGHTNING WALLET',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Color(0xFF00cc33),
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 32),

          // ─── Connect box ───────────────────────────────────
          _TerminalBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '> CONNECT WALLET',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: Color(0xFF00ff41),
                    fontSize: 13,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  style: const TextStyle(
                    color: Color(0xFF00ff41),
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                  decoration: InputDecoration(
                    labelText: 'LNDHub URL',
                    hintText:
                        'lndhub://login:password@https://...',
                    suffixIcon: IconButton(
                      icon: const Icon(
                        Icons.qr_code_scanner,
                        color: Color(0xFFF7931A),
                      ),
                      onPressed: () =>
                          setState(() => _scanning = true),
                    ),
                  ),
                  maxLines: 3,
                  minLines: 1,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed:
                        provider.isLoading ? null : _connect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF7931A)
                          .withOpacity(0.15),
                      side: const BorderSide(
                          color: Color(0xFFF7931A), width: 2),
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero),
                    ),
                    child: provider.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Color(0xFFF7931A),
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'CONNECT',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF7931A),
                              letterSpacing: 2,
                            ),
                          ),
                  ),
                ),

                // ─── Error display ─────────────────────────
                if (_detailedError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFFff4444)
                            .withOpacity(0.5),
                      ),
                      color: const Color(0xFFff4444)
                          .withOpacity(0.05),
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '✗ ',
                          style: TextStyle(
                              color: Color(0xFFff4444)),
                        ),
                        Expanded(
                          child: Text(
                            _detailedError!,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Color(0xFFff4444),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── Info box ──────────────────────────────────────
          _TerminalBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '> ABOUT LNDHUB',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: Color(0xFF00ff41),
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: 12),
                _InfoRow(
                  icon: '>',
                  text: 'Connect to any LNDHub compatible wallet.',
                  color: Color(0xFF00cc33),
                ),
                SizedBox(height: 8),
                _InfoRow(
                  icon: '>',
                  text: 'Works with LNBits, Alby Hub, Citadel, BTCPay Server & more.',
                  color: Color(0xFF00cc33),
                ),
                SizedBox(height: 8),
                _InfoRow(
                  icon: '>',
                  text:
                      'Scan your wallet QR code or paste the lndhub:// URL.',
                  color: Color(0xFF00cc33),
                ),
                SizedBox(height: 8),
                _InfoRow(
                  icon: '⚠',
                  text:
                      'Custodial — your funds are held by the server. Only use small amounts.',
                  color: Color(0xFFff4444),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ─── Footer ────────────────────────────────────────
          const Text(
            'Morpheus — Lightning Network Wallet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              color: Color(0xFF005511),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(
          onDetect: (capture) {
            final barcode = capture.barcodes.firstOrNull;
            if (barcode?.rawValue != null) {
              setState(() {
                _scanning = false;
                _controller.text = barcode!.rawValue!;
              });
            }
          },
        ),
        Positioned(
          top: 16,
          left: 16,
          child: IconButton(
            icon: const Icon(
              Icons.close,
              color: Color(0xFF00ff41),
              size: 32,
            ),
            onPressed: () => setState(() => _scanning = false),
          ),
        ),
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFFF7931A),
                width: 2,
              ),
            ),
          ),
        ),
        const Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Text(
            'SCAN LNDHUB QR CODE',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'monospace',
              color: Color(0xFF00ff41),
              letterSpacing: 2,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// ─── Info row ───────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final String icon;
  final String text;
  final Color color;

  const _InfoRow({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$icon ',
          style: TextStyle(
            color: color,
            fontSize: 12,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: color,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Shared widgets ─────────────────────────────────────────
class _GridBackground extends StatelessWidget {
  const _GridBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GridPainter(),
      child: const SizedBox.expand(),
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

class _TerminalBox extends StatelessWidget {
  final Widget child;
  const _TerminalBox({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color(0xFF00ff41).withOpacity(0.3),
        ),
        color: const Color(0xFF00ff41).withOpacity(0.03),
      ),
      child: child,
    );
  }
}
