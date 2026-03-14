import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/wallet_provider.dart';
import '../services/bookmark_service.dart';
import 'payment_success_screen.dart';
import 'invoice_preview_screen.dart';

enum _SendMode { invoice, lightningAddress }

class SendScreen extends StatefulWidget {
  final String? prefillAddress;
  const SendScreen({super.key, this.prefillAddress});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _invoiceController = TextEditingController();
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  final _commentController = TextEditingController();
  bool _scanning = false;
  bool _loading = false;
  _SendMode _mode = _SendMode.invoice;

  @override
  void initState() {
    super.initState();
    if (widget.prefillAddress != null) {
      _mode = _SendMode.lightningAddress;
      _addressController.text = widget.prefillAddress!;
    }
  }

  Future<void> _payInvoice() async {
    final invoice = _invoiceController.text.trim();
    if (invoice.isEmpty) {
      _showError('Please enter a lightning invoice');
      return;
    }

    setState(() => _loading = true);
    final provider = context.read<WalletProvider>();
    final balanceBefore = provider.balance;
    final error = await provider.payInvoice(invoice);
    setState(() => _loading = false);

    if (!mounted) return;

    if (error == null) {
      final amountPaid = (balanceBefore - provider.balance).abs();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentSuccessScreen(
            isSend: true,
            amountSats: amountPaid > 0 ? amountPaid : null,
            memo: '',
          ),
        ),
      );
    } else {
      _showError(error);
    }
  }

  Future<void> _payAddress() async {
    final address = _addressController.text.trim();
    final amount = int.tryParse(_amountController.text.trim());

    if (address.isEmpty) {
      _showError('Please enter a lightning address');
      return;
    }
    if (!address.contains('@')) {
      _showError('Invalid lightning address — use format user@domain.com');
      return;
    }
    if (amount == null || amount <= 0) {
      _showError('Please enter a valid amount in sats');
      return;
    }

    setState(() => _loading = true);
    final provider = context.read<WalletProvider>();
    final error = await provider.payLightningAddress(
      address: address,
      amountSats: amount,
      comment: _commentController.text.trim(),
    );
    setState(() => _loading = false);

    if (!mounted) return;

    if (error == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentSuccessScreen(
            isSend: true,
            amountSats: amount,
            memo: _commentController.text.trim(),
          ),
        ),
      );
    } else {
      _showError(error);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0a0e0a),
        duration: const Duration(seconds: 5),
        content: Row(
          children: [
            const Text('✗ ', style: TextStyle(color: Color(0xFFff4444), fontSize: 16)),
            Expanded(
              child: Text(
                msg,
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

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0a0e0a),
        content: Text(
          '✓ $msg',
          style: const TextStyle(
            color: Color(0xFF00ff41),
            fontFamily: 'monospace',
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  void _showBookmarkDialog() {
    final labelController = TextEditingController();
    final addressToSave = _addressController.text.trim();

    if (addressToSave.isEmpty || !addressToSave.contains('@')) {
      _showError('Enter a valid lightning address first');
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0d120d),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          '> SAVE BOOKMARK',
          style: TextStyle(
            fontFamily: 'monospace',
            color: Color(0xFF00ff41),
            fontSize: 14,
            letterSpacing: 2,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              autofocus: true,
              style: const TextStyle(
                  color: Color(0xFF00ff41), fontFamily: 'monospace'),
              decoration: const InputDecoration(
                labelText: 'LABEL',
                hintText: 'e.g. Alice, My Node...',
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              color: const Color(0xFF00ff41).withOpacity(0.05),
              child: Text(
                addressToSave,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: Color(0xFF00cc33),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'CANCEL',
              style: TextStyle(
                  fontFamily: 'monospace', color: Color(0xFF005511)),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (labelController.text.trim().isEmpty) return;
              await context.read<WalletProvider>().addBookmark(
                    labelController.text.trim(),
                    addressToSave,
                  );
              if (!mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Color(0xFF0a0e0a),
                  content: Text(
                    '✓ BOOKMARK SAVED',
                    style: TextStyle(
                        color: Color(0xFF00ff41), fontFamily: 'monospace'),
                  ),
                ),
              );
            },
            child: const Text(
              'SAVE',
              style: TextStyle(
                  fontFamily: 'monospace', color: Color(0xFFF7931A)),
            ),
          ),
        ],
      ),
    );
  }

  void _showBookmarkPicker() {
    final bookmarks = context.read<WalletProvider>().bookmarks;

    if (bookmarks.isEmpty) {
      _showError('No bookmarks saved yet');
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0d120d),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          '> SELECT BOOKMARK',
          style: TextStyle(
            fontFamily: 'monospace',
            color: Color(0xFF00ff41),
            fontSize: 14,
            letterSpacing: 2,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Consumer<WalletProvider>(
            builder: (_, provider, __) => ListView.builder(
              shrinkWrap: true,
              itemCount: provider.bookmarks.length,
              itemBuilder: (_, index) {
                final b = provider.bookmarks[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: const Color(0xFF00ff41).withOpacity(0.2)),
                    color: const Color(0xFF00ff41).withOpacity(0.03),
                  ),
                  child: ListTile(
                    dense: true,
                    title: Text(
                      b.label,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Color(0xFFF7931A),
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      b.address,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Color(0xFF00cc33),
                        fontSize: 11,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Color(0xFF550000), size: 18),
                      onPressed: () async {
                        await provider.deleteBookmark(b.id);
                      },
                    ),
                    onTap: () {
                      _addressController.text = b.address;
                      Navigator.pop(ctx);
                    },
                  ),
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'CLOSE',
              style: TextStyle(
                  fontFamily: 'monospace', color: Color(0xFF005511)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0e0a),
      appBar: AppBar(title: const Text('SEND')),
      body: Stack(
        children: [
          CustomPaint(painter: _GridPainter(), child: const SizedBox.expand()),
          _scanning ? _buildScanner() : _buildForm(),
          if (_loading) const _SendingOverlay(),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // Mode toggle
          Row(
            children: [
              Expanded(
                child: _ModeButton(
                  label: 'INVOICE',
                  active: _mode == _SendMode.invoice,
                  onTap: () => setState(() => _mode = _SendMode.invoice),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ModeButton(
                  label: 'LN ADDRESS',
                  active: _mode == _SendMode.lightningAddress,
                  onTap: () =>
                      setState(() => _mode = _SendMode.lightningAddress),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_mode == _SendMode.invoice) _buildInvoiceForm(),
          if (_mode == _SendMode.lightningAddress) _buildAddressForm(),
          const SizedBox(height: 28),
          const _SatsConverterBanner(),
        ],
      ),
    );
  }

  Widget _buildInvoiceForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '> PAY BOLT11 INVOICE',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: Color(0xFF00cc33),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _invoiceController,
          style: const TextStyle(
              color: Color(0xFF00ff41), fontFamily: 'monospace', fontSize: 12),
          decoration: const InputDecoration(
            labelText: 'LIGHTNING INVOICE',
            hintText: 'lnbc...',
            prefixIcon: Icon(Icons.bolt, color: Color(0xFFF7931A)),
          ),
          maxLines: 4,
          minLines: 1,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.content_paste,
                label: 'PASTE',
                color: const Color(0xFF00ff41),
                onTap: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null) {
                    _invoiceController.text = data!.text!.trim();
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                icon: Icons.qr_code_scanner,
                label: 'SCAN',
                color: const Color(0xFFF7931A),
                onTap: () => setState(() => _scanning = true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _loading
                ? null
                : () {
                    final invoice = _invoiceController.text.trim();
                    if (invoice.isEmpty) {
                      _showError('Please enter a lightning invoice');
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            InvoicePreviewScreen(invoice: invoice),
                      ),
                    );
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF7931A).withOpacity(0.1),
              side: const BorderSide(color: Color(0xFFF7931A), width: 2),
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero),
            ),
            child: const Text(
              'PREVIEW & PAY',
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                color: Color(0xFFF7931A),
                letterSpacing: 2,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddressForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '> PAY LIGHTNING ADDRESS',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: Color(0xFF00cc33),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _addressController,
          style: const TextStyle(
              color: Color(0xFF00ff41), fontFamily: 'monospace', fontSize: 13),
          decoration: InputDecoration(
            labelText: 'LIGHTNING ADDRESS',
            hintText: 'user@domain.com',
            prefixIcon: const Icon(Icons.alternate_email,
                color: Color(0xFFF7931A)),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.bookmark_border,
                      color: Color(0xFF00ff41), size: 20),
                  tooltip: 'Save bookmark',
                  onPressed: _showBookmarkDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.bookmarks,
                      color: Color(0xFFF7931A), size: 20),
                  tooltip: 'Load bookmark',
                  onPressed: _showBookmarkPicker,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          style: const TextStyle(
              color: Color(0xFF00ff41), fontFamily: 'monospace'),
          decoration: const InputDecoration(
            labelText: 'AMOUNT (sats)',
            prefixIcon: Icon(Icons.bolt, color: Color(0xFFF7931A)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _commentController,
          style: const TextStyle(
              color: Color(0xFF00ff41), fontFamily: 'monospace'),
          decoration: const InputDecoration(
            labelText: 'COMMENT (optional)',
            prefixIcon: Icon(Icons.notes, color: Color(0xFF00ff41)),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _loading ? null : _payAddress,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF7931A).withOpacity(0.1),
              side: const BorderSide(color: Color(0xFFF7931A), width: 2),
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero),
            ),
            child: const Text(
                    'PAY ADDRESS',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF7931A),
                      letterSpacing: 2,
                      fontSize: 15,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 24),
        _BookmarksList(),
      ],
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(
          onDetect: (capture) {
            final barcode = capture.barcodes.firstOrNull;
            if (barcode?.rawValue != null) {
              final scanned = barcode!.rawValue!;
              setState(() => _scanning = false);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InvoicePreviewScreen(invoice: scanned),
                ),
              );
            }
          },
        ),
        Positioned(
          top: 16,
          left: 16,
          child: IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF00ff41), size: 32),
            onPressed: () => setState(() => _scanning = false),
          ),
        ),
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFF7931A), width: 2),
            ),
          ),
        ),
        const Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Text(
            'SCAN LIGHTNING INVOICE',
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
    _invoiceController.dispose();
    _addressController.dispose();
    _amountController.dispose();
    _commentController.dispose();
    super.dispose();
  }
}

// ─── Bookmarks list shown inside address form ──────────────
class _BookmarksList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bookmarks = context.watch<WalletProvider>().bookmarks;

    if (bookmarks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '> SAVED ADDRESSES',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: Color(0xFF00cc33),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        ...bookmarks.map(
          (b) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              border: Border.all(
                  color: const Color(0xFF00ff41).withOpacity(0.2)),
              color: const Color(0xFF00ff41).withOpacity(0.03),
            ),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.bolt,
                  color: Color(0xFFF7931A), size: 18),
              title: Text(
                b.label,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: Color(0xFFF7931A),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                b.address,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: Color(0xFF00cc33),
                  fontSize: 11,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Color(0xFF550000), size: 18),
                onPressed: () =>
                    context.read<WalletProvider>().deleteBookmark(b.id),
              ),
              onTap: () {
                // Fill address field in parent — use callback via ancestor
                final state = context
                    .findAncestorStateOfType<_SendScreenState>();
                if (state != null) {
                  state._addressController.text = b.address;
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Mode toggle button ────────────────────────────────────
class _ModeButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: active
                ? const Color(0xFFF7931A)
                : const Color(0xFF00ff41).withOpacity(0.2),
            width: active ? 2 : 1,
          ),
          color: active
              ? const Color(0xFFF7931A).withOpacity(0.1)
              : Colors.transparent,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: active
                ? const Color(0xFFF7931A)
                : const Color(0xFF00ff41).withOpacity(0.4),
          ),
        ),
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
            // Spinning arc + bolt
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
                final dots = '.' * ((_dotsController.value * 4).floor() % 4);
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

// ─── Paste / Scan action button ────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
          color: color.withOpacity(0.06),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SatsConverterBanner extends StatelessWidget {
  const _SatsConverterBanner();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => launchUrl(
        Uri.parse('https://satsconverter.app'),
        mode: LaunchMode.externalApplication,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFF7931A).withOpacity(0.3)),
          color: const Color(0xFFF7931A).withOpacity(0.04),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.currency_bitcoin, color: Color(0xFFF7931A), size: 16),
            SizedBox(width: 8),
            Text(
              'CONVERT SATS AT SATSCONVERTER.APP',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Color(0xFFF7931A),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
