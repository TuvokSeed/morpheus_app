import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/wallet_provider.dart';
import 'payment_success_screen.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();

  String? _invoice;
  bool _loading = false;
  bool _polling = false;
  Timer? _pollTimer;

  // We snapshot the paid invoice IDs BEFORE creating the invoice.
  // Then after creation, we poll and compare — any NEW paid invoice
  // that was not in the snapshot is our payment.
  Set<String> _paidHashesBeforeInvoice = {};

  @override
  void dispose() {
    _pollTimer?.cancel();
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  // ─── Step 1: Snapshot existing paid invoices ────────────────
  Future<Set<String>> _snapshotPaidInvoices() async {
    try {
      final service = context.read<WalletProvider>().service;
      final invoices = await service.getUserInvoices();
      final paid = <String>{};
      for (final inv in invoices) {
        final isPaid = inv['ispaid'] == true ||
            inv['ispaid'] == 1 ||
            inv['type'] == 'user_invoice' && inv['ispaid'] != false;
        if (isPaid) {
          // Use every available identifier
          final h1 = inv['r_hash']?.toString() ?? '';
          final h2 = inv['payment_hash']?.toString() ?? '';
          final h3 = inv['id']?.toString() ?? '';
          final ts = inv['timestamp']?.toString() ?? '';
          final amt = inv['amt']?.toString() ?? inv['value']?.toString() ?? '';
          if (h1.isNotEmpty) paid.add(h1);
          if (h2.isNotEmpty) paid.add(h2);
          if (h3.isNotEmpty) paid.add(h3);
          // Also add a composite key as fallback
          if (ts.isNotEmpty && amt.isNotEmpty) paid.add('$ts-$amt');
        }
      }
      return paid;
    } catch (_) {
      return {};
    }
  }

  // ─── Step 2: Generate invoice ───────────────────────────────
  Future<void> _generate() async {
    final amount = int.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showError('Enter a valid amount in sats');
      return;
    }

    setState(() => _loading = true);

    try {
      // Snapshot BEFORE creating invoice
      _paidHashesBeforeInvoice = await _snapshotPaidInvoices();

      final result = await context.read<WalletProvider>().createInvoice(
            amount,
            _memoController.text,
          );

      final invoice = result['payment_request'] as String?;
      if (invoice == null || invoice.isEmpty) {
        _showError('Failed to generate invoice');
        setState(() => _loading = false);
        return;
      }

      setState(() {
        _invoice = invoice;
        _polling = true;
        _loading = false;
      });

      _startPolling();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) _showError('$e');
    }
  }

  // ─── Step 3: Poll every 3s for new paid invoice ─────────────
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) {
        _pollTimer?.cancel();
        return;
      }
      await _checkForPayment();
    });
  }

  Future<void> _checkForPayment() async {
    try {
      final service = context.read<WalletProvider>().service;
      final invoices = await service.getUserInvoices();

      for (final inv in invoices) {
        // Strict paid check
        final isPaid = inv['ispaid'] == true || inv['ispaid'] == 1;
        if (!isPaid) continue;

        // Build identifiers for this invoice
        final h1 = inv['r_hash']?.toString() ?? '';
        final h2 = inv['payment_hash']?.toString() ?? '';
        final h3 = inv['id']?.toString() ?? '';
        final ts = inv['timestamp']?.toString() ?? '';
        final amt =
            inv['amt']?.toString() ?? inv['value']?.toString() ?? '';
        final compositeKey = '$ts-$amt';

        // Check if this paid invoice is NEW (not in our snapshot)
        final isNew = (!_paidHashesBeforeInvoice.contains(h1) ||
                h1.isEmpty) &&
            (!_paidHashesBeforeInvoice.contains(h2) || h2.isEmpty) &&
            (!_paidHashesBeforeInvoice.contains(h3) || h3.isEmpty) &&
            !_paidHashesBeforeInvoice.contains(compositeKey);

        // At least one identifier must be non-empty and new
        final hasNewIdentifier =
            (h1.isNotEmpty && !_paidHashesBeforeInvoice.contains(h1)) ||
                (h2.isNotEmpty &&
                    !_paidHashesBeforeInvoice.contains(h2)) ||
                (h3.isNotEmpty &&
                    !_paidHashesBeforeInvoice.contains(h3)) ||
                (ts.isNotEmpty &&
                    amt.isNotEmpty &&
                    !_paidHashesBeforeInvoice.contains(compositeKey));

        if (hasNewIdentifier) {
          _pollTimer?.cancel();

          final paidAmount = int.tryParse(amt) ??
              (inv['amt'] as int? ?? inv['value'] as int? ?? 0);
          final memo = inv['memo'] as String? ??
              inv['description'] as String? ?? '';

          if (!mounted) return;

          // Refresh wallet balance
          await context.read<WalletProvider>().refreshAll();

          if (!mounted) return;

          setState(() => _polling = false);

          // Navigate to success screen
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, animation, __) => PaymentSuccessScreen(
                amountSats: paidAmount,
                memo: memo,
              ),
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
          return;
        }
      }
    } catch (_) {
      // Silently continue polling on network errors
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0a0e0a),
        content: Text(
          'ERROR: $msg',
          style: const TextStyle(
            color: Color(0xFFff4444),
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }

  void _cancelInvoice() {
    _pollTimer?.cancel();
    setState(() {
      _invoice = null;
      _polling = false;
      _paidHashesBeforeInvoice = {};
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0e0a),
      appBar: AppBar(
        title: const Text('RECEIVE'),
        actions: [
          if (_polling)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      color: Color(0xFF00ff41),
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'WATCHING',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Color(0xFF00ff41),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          CustomPaint(
            painter: _GridPainter(),
            child: const SizedBox.expand(),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _invoice == null ? _buildForm() : _buildQR(),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          '> CREATE INVOICE',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: Color(0xFF00cc33),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          style: const TextStyle(
            color: Color(0xFF00ff41),
            fontFamily: 'monospace',
          ),
          decoration: const InputDecoration(
            labelText: 'AMOUNT (sats)',
            prefixIcon: Icon(Icons.bolt, color: Color(0xFFF7931A)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _memoController,
          style: const TextStyle(
            color: Color(0xFF00ff41),
            fontFamily: 'monospace',
          ),
          decoration: const InputDecoration(
            labelText: 'MEMO (optional)',
            prefixIcon: Icon(Icons.notes, color: Color(0xFF00ff41)),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _loading ? null : _generate,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00ff41).withOpacity(0.1),
              side: const BorderSide(color: Color(0xFF00ff41), width: 2),
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero),
            ),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Color(0xFF00ff41),
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'GENERATE INVOICE',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00ff41),
                      letterSpacing: 2,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: () => launchUrl(
            Uri.parse('https://satsconverter.app'),
            mode: LaunchMode.externalApplication,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                  color: const Color(0xFFF7931A).withOpacity(0.3)),
              color: const Color(0xFFF7931A).withOpacity(0.04),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.currency_bitcoin,
                    color: Color(0xFFF7931A), size: 16),
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
        ),
      ],
    );
  }

  Widget _buildQR() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status bar
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF00ff41).withOpacity(0.06),
            border: Border.all(
                color: const Color(0xFF00ff41).withOpacity(0.2)),
          ),
          child: Row(
            children: [
              if (_polling)
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    color: Color(0xFF00ff41),
                    strokeWidth: 2,
                  ),
                ),
              if (_polling) const SizedBox(width: 8),
              Text(
                _polling
                    ? '> WAITING FOR PAYMENT...'
                    : '> INVOICE READY',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Color(0xFF00cc33),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // QR Code
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border:
                  Border.all(color: const Color(0xFFF7931A), width: 3),
            ),
            child: QrImageView(
              data: _invoice!.toUpperCase(),
              version: QrVersions.auto,
              size: 240,
              backgroundColor: Colors.white,
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Invoice text
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
                color: const Color(0xFF00ff41).withOpacity(0.3)),
            color: const Color(0xFF00ff41).withOpacity(0.03),
          ),
          child: SelectableText(
            _invoice!,
            style: const TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              color: Color(0xFF00cc33),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Buttons
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _invoice!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: Color(0xFF0a0e0a),
                        content: Text(
                          '✓ COPIED TO CLIPBOARD',
                          style: TextStyle(
                            color: Color(0xFF00ff41),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFFF7931A).withOpacity(0.1),
                    side: const BorderSide(
                        color: Color(0xFFF7931A), width: 2),
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero),
                  ),
                  child: const Text(
                    'COPY',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: Color(0xFFF7931A),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _cancelInvoice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF00ff41).withOpacity(0.1),
                    side: const BorderSide(
                        color: Color(0xFF00ff41), width: 2),
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: Color(0xFF00ff41),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
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
