import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import 'connect_screen.dart';
import 'receive_screen.dart';
import 'send_screen.dart';
import 'transactions_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => context.read<WalletProvider>().refreshAll());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WalletProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0a0e0a),
      appBar: AppBar(
        title: const Text('MORPHEUS'),
        leading: IconButton(
          icon: provider.isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Color(0xFF00ff41),
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.refresh, color: Color(0xFF00ff41)),
          onPressed: provider.isLoading ? null : provider.refreshAll,
          tooltip: 'Refresh',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Color(0xFF00ff41)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Stack(
        children: [
          CustomPaint(
            painter: _GridPainter(),
            child: const SizedBox.expand(),
          ),
          RefreshIndicator(
            onRefresh: provider.refreshAll,
            color: const Color(0xFFF7931A),
            backgroundColor: const Color(0xFF0a0e0a),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _BalanceCard(
                    balance: provider.balance,
                    loading: provider.isLoading,
                  ),
                  const SizedBox(height: 16),
                  const _ActionButtons(),
                  const SizedBox(height: 16),
                  _RecentTransactions(
                      transactions: provider.transactions),
                  const SizedBox(height: 32),
                  const _Footer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final int balance;
  final bool loading;

  const _BalanceCard(
      {required this.balance, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF00ff41).withOpacity(0.03),
        border: Border.all(
          color: const Color(0xFF00ff41).withOpacity(0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '> BALANCE',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Color(0xFF00cc33),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          loading
              ? const SizedBox(
                  height: 48,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFF7931A),
                      strokeWidth: 2,
                    ),
                  ),
                )
              : Text(
                  '$balance sats',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00ff41),
                    shadows: [
                      Shadow(
                          color: Color(0xFF00ff41),
                          blurRadius: 8),
                    ],
                  ),
                ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF00ff41),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'LIGHTNING NETWORK — ONLINE',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: Color(0xFF00cc33),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TerminalButton(
            label: 'RECEIVE',
            color: const Color(0xFF00ff41),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ReceiveScreen()),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TerminalButton(
            label: 'SEND',
            color: const Color(0xFFF7931A),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const SendScreen()),
            ),
          ),
        ),
      ],
    );
  }
}

class _TerminalButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _TerminalButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.1),
          side: BorderSide(color: color, width: 2),
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            color: color,
            letterSpacing: 2,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _RecentTransactions extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;

  const _RecentTransactions({required this.transactions});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '> RECENT TX',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Color(0xFF00cc33),
                letterSpacing: 2,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        const TransactionsScreen()),
              ),
              child: const Text(
                'SEE ALL >>',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Color(0xFFF7931A),
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: const Color(0xFF00ff41).withOpacity(0.2),
            ),
          ),
          child: transactions.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      '> NO TRANSACTIONS YET_',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: Color(0xFF005511),
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: transactions
                      .take(5)
                      .map((tx) => _TxRow(tx: tx))
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _TxRow extends StatelessWidget {
  final Map<String, dynamic> tx;

  const _TxRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isOut = tx['_direction'] == 'sent';
    final amount = tx['_amount'] as int? ?? 0;
    final memo = tx['_memo'] as String? ?? '';
    final ts =
        tx['_timestamp'] != null && tx['_timestamp'] != 0
            ? DateTime.fromMillisecondsSinceEpoch(
                (tx['_timestamp'] as int) * 1000)
            : null;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF00ff41).withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              border: Border.all(
                color: isOut
                    ? const Color(0xFFF7931A).withOpacity(0.5)
                    : const Color(0xFF00ff41).withOpacity(0.5),
              ),
              color: isOut
                  ? const Color(0xFFF7931A).withOpacity(0.08)
                  : const Color(0xFF00ff41).withOpacity(0.08),
            ),
            child: Center(
              child: Text(
                isOut ? '↑' : '↓',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isOut
                      ? const Color(0xFFF7931A)
                      : const Color(0xFF00ff41),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  memo.isNotEmpty
                      ? memo
                      : (isOut ? 'SENT' : 'RECEIVED'),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
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
          Text(
            '${isOut ? '-' : '+'}$amount sats',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isOut
                  ? const Color(0xFFF7931A)
                  : const Color(0xFF00ff41),
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
              color: const Color(0xFF00ff41).withOpacity(0.2)),
        ),
      ),
      child: const Text(
        'Morpheus — Lightning Network Wallet',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          color: Color(0xFF005511),
          letterSpacing: 1,
        ),
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
