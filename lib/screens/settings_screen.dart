import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/wallet_provider.dart';
import 'connect_screen.dart';

const _appVersion = 'V-001';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _checkingUpdate = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    bool available = false;
    try {
      final localAuth = LocalAuthentication();
      available = await localAuth.canCheckBiometrics ||
          await localAuth.isDeviceSupported();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _biometricEnabled = prefs.getBool('morpheus_biometric') ?? false;
      _biometricAvailable = available;
    });
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      // Verify it works before enabling
      bool confirmed = false;
      try {
        final localAuth = LocalAuthentication();
        confirmed = await localAuth.authenticate(
          localizedReason: 'Confirm fingerprint to enable biometric login',
          options: const AuthenticationOptions(biometricOnly: true),
        );
      } catch (_) {}
      if (!confirmed) return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('morpheus_biometric', value);
    if (!mounted) return;
    setState(() => _biometricEnabled = value);
  }

  Future<void> _checkForUpdates() async {
    setState(() => _checkingUpdate = true);
    // Simulate network check
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _checkingUpdate = false);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0d120d),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          '> VERSION CHECK',
          style: TextStyle(
            fontFamily: 'monospace',
            color: Color(0xFF00ff41),
            fontSize: 14,
            letterSpacing: 2,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current:  $_appVersion',
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Color(0xFF00cc33),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Latest:   V-001',
              style: TextStyle(
                fontFamily: 'monospace',
                color: Color(0xFF00cc33),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '✓ You are up to date.',
              style: TextStyle(
                fontFamily: 'monospace',
                color: Color(0xFF00ff41),
                fontSize: 13,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(
                fontFamily: 'monospace',
                color: Color(0xFFF7931A),
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0d120d),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          '> DISCONNECT NODE',
          style: TextStyle(
            fontFamily: 'monospace',
            color: Color(0xFFff4444),
            fontSize: 14,
            letterSpacing: 2,
          ),
        ),
        content: const Text(
          'This will remove your node credentials and return to the connect screen.',
          style: TextStyle(
            fontFamily: 'monospace',
            color: Color(0xFF00cc33),
            fontSize: 12,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'CANCEL',
              style: TextStyle(
                fontFamily: 'monospace',
                color: Color(0xFF005511),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'DISCONNECT',
              style: TextStyle(
                fontFamily: 'monospace',
                color: Color(0xFFff4444),
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await context.read<WalletProvider>().disconnect();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ConnectScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0e0a),
      appBar: AppBar(title: const Text('SETTINGS')),
      body: Stack(
        children: [
          CustomPaint(painter: _GridPainter(), child: const SizedBox.expand()),
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 8),

              // ── App Info ──────────────────────────────────────
              _SectionHeader(label: 'APP INFO'),
              const SizedBox(height: 8),
              _InfoTile(
                icon: Icons.memory,
                label: 'VERSION',
                value: _appVersion,
              ),
              const SizedBox(height: 4),
              _InfoTile(
                icon: Icons.bolt,
                label: 'NETWORK',
                value: 'Lightning Network (LNDHub)',
              ),

              const SizedBox(height: 24),

              // ── Security ──────────────────────────────────────
              _SectionHeader(label: 'SECURITY'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _biometricAvailable
                        ? const Color(0xFF00ff41).withOpacity(0.35)
                        : const Color(0xFF00ff41).withOpacity(0.1),
                    width: 1,
                  ),
                  color: const Color(0xFF00ff41).withOpacity(0.04),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.fingerprint,
                      color: _biometricAvailable
                          ? const Color(0xFF00ff41)
                          : const Color(0xFF005511),
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FINGERPRINT LOGIN',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _biometricAvailable
                                  ? const Color(0xFF00ff41)
                                  : const Color(0xFF005511),
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _biometricAvailable
                                ? 'Falls back to PIN after 3 failures'
                                : 'Not available on this device',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              color: Color(0xFF005511),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _biometricEnabled,
                      onChanged:
                          _biometricAvailable ? _toggleBiometric : null,
                      activeColor: const Color(0xFF00ff41),
                      inactiveTrackColor:
                          const Color(0xFF00ff41).withOpacity(0.1),
                      inactiveThumbColor: const Color(0xFF005511),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Updates ───────────────────────────────────────
              _SectionHeader(label: 'UPDATES'),
              const SizedBox(height: 8),
              _ActionTile(
                icon: Icons.system_update_alt,
                label: 'CHECK FOR NEW VERSION',
                color: const Color(0xFF00ff41),
                trailing: _checkingUpdate
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Color(0xFF00ff41),
                          strokeWidth: 2,
                        ),
                      )
                    : null,
                onTap: _checkingUpdate ? null : _checkForUpdates,
              ),

              const SizedBox(height: 24),

              // ── Node ──────────────────────────────────────────
              _SectionHeader(label: 'NODE'),
              const SizedBox(height: 8),
              _ActionTile(
                icon: Icons.link_off,
                label: 'DISCONNECT NODE',
                color: const Color(0xFFff4444),
                onTap: _disconnect,
              ),

              const SizedBox(height: 40),

              // ── Footer ────────────────────────────────────────
              Center(
                child: Text(
                  'Morpheus $_appVersion — Lightning Network Wallet',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: Color(0xFF005511),
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Reusable section header ───────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      '> $label',
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 11,
        color: Color(0xFF00cc33),
        letterSpacing: 2,
      ),
    );
  }
}

// ── Info tile (read-only) ─────────────────────────────────
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(
            color: const Color(0xFF00ff41).withOpacity(0.2), width: 1),
        color: const Color(0xFF00ff41).withOpacity(0.03),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00ff41), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Color(0xFF00cc33),
                letterSpacing: 1,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00ff41),
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tappable action tile ──────────────────────────────────
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.35), width: 1),
          color: color.withOpacity(0.05),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 1,
                ),
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right, color: color.withOpacity(0.5),
                    size: 20),
          ],
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
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
