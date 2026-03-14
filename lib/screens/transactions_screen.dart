import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final transactions = context.watch<WalletProvider>().transactions;

    return Scaffold(
      backgroundColor: const Color(0xFF0a0e0a),
      appBar: AppBar(title: const Text('TX HISTORY')),
      body: Stack(
        children: [
          CustomPaint(
            painter: _GridPainter(),
            child: const SizedBox.expand(),
          ),
          transactions.isEmpty
              ? const Center(
                  child: Text(
                    '> NO TRANSACTIONS YET_',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: Color(0xFF005511),
                      fontSize: 13,
                      letterSpacing: 1,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    final isOut = tx['_direction'] == 'sent';
                    final amount = tx['_amount'] as int? ?? 0;
                    final memo = tx['_memo'] as String? ?? '';
                    final ts = tx['_timestamp'] != null &&
                            tx['_timestamp'] != 0
                        ? DateTime.fromMillisecondsSinceEpoch(
                            (tx['_timestamp'] as int) * 1000,
                          )
                        : null;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: const Color(0xFF00ff41)
                                .withOpacity(0.1),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Direction box
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isOut
                                    ? const Color(0xFFF7931A)
                                        .withOpacity(0.5)
                                    : const Color(0xFF00ff41)
                                        .withOpacity(0.5),
                              ),
                              color: isOut
                                  ? const Color(0xFFF7931A)
                                      .withOpacity(0.08)
                                  : const Color(0xFF00ff41)
                                      .withOpacity(0.08),
                            ),
                            child: Center(
                              child: Text(
                                isOut ? '↑' : '↓',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isOut
                                      ? const Color(0xFFF7931A)
                                      : const Color(0xFF00ff41),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Memo + date
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  memo.isNotEmpty
                                      ? memo
                                      : (isOut
                                          ? 'SENT'
                                          : 'RECEIVED'),
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 13,
                                    color: Color(0xFF00ff41),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (ts != null)
                                  Text(
                                    '${ts.day.toString().padLeft(2, '0')}/'
                                    '${ts.month.toString().padLeft(2, '0')}/'
                                    '${ts.year} '
                                    '${ts.hour.toString().padLeft(2, '0')}:'
                                    '${ts.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                      color: Color(0xFF005511),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Amount
                          Text(
                            '${isOut ? '-' : '+'}$amount sats',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isOut
                                  ? const Color(0xFFF7931A)
                                  : const Color(0xFF00ff41),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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
      canvas.drawLine(
          Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
