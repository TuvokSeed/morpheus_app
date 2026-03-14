import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PinMode { create, enter }

class PinScreen extends StatefulWidget {
  final PinMode mode;
  final Widget Function() nextScreen;

  const PinScreen({
    super.key,
    required this.mode,
    required this.nextScreen,
  });

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen>
    with SingleTickerProviderStateMixin {
  static const _pinLength = 5;
  static const _prefKey  = 'morpheus_pin';

  String _input    = '';
  String _firstPin = '';         // used during create → confirm step
  bool   _confirming = false;    // create mode: re-enter to confirm
  String? _errorMsg;

  late AnimationController _shakeCtrl;
  late Animation<double>   _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onKey(String digit) {
    if (_input.length >= _pinLength) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _input += digit;
      _errorMsg = null;
    });
    if (_input.length == _pinLength) _handleComplete();
  }

  void _onDelete() {
    if (_input.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  Future<void> _handleComplete() async {
    if (widget.mode == PinMode.create) {
      if (!_confirming) {
        // First entry — ask to confirm
        setState(() {
          _firstPin    = _input;
          _input       = '';
          _confirming  = true;
        });
      } else {
        // Confirm entry
        if (_input == _firstPin) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefKey, _input);
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => widget.nextScreen()),
          );
        } else {
          _shakeCtrl.forward(from: 0);
          setState(() {
            _errorMsg   = 'PINS DO NOT MATCH — TRY AGAIN';
            _input      = '';
            _firstPin   = '';
            _confirming = false;
          });
        }
      }
    } else {
      // Enter mode — verify
      final prefs    = await SharedPreferences.getInstance();
      final stored   = prefs.getString(_prefKey);
      if (_input == stored) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => widget.nextScreen()),
        );
      } else {
        _shakeCtrl.forward(from: 0);
        setState(() {
          _errorMsg = 'WRONG PIN';
          _input    = '';
        });
      }
    }
  }

  String get _title {
    if (widget.mode == PinMode.enter) return 'ENTER PIN';
    return _confirming ? 'CONFIRM PIN' : 'CREATE PIN';
  }

  String get _subtitle {
    if (widget.mode == PinMode.enter) return '> identify yourself';
    return _confirming
        ? '> re-enter your 5-digit pin'
        : '> choose a 5-digit pin';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0e0a),
      body: Stack(
        children: [
          CustomPaint(painter: _GridPainter(), child: const SizedBox.expand()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF7931A).withOpacity(0.08),
                          border: Border.all(
                              color: const Color(0xFFF7931A), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF7931A).withOpacity(0.3),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/icon/icon.png',
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      Text(
                        _title,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00ff41),
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _subtitle,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Color(0xFF00cc33),
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Dots
                      AnimatedBuilder(
                        animation: _shakeAnim,
                        builder: (_, child) => Transform.translate(
                          offset: Offset(
                            _shakeAnim.value *
                                12 *
                                (0.5 - (_shakeAnim.value % 0.25) / 0.25),
                            0,
                          ),
                          child: child,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_pinLength, (i) {
                            final filled = i < _input.length;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: filled
                                    ? const Color(0xFFF7931A)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: filled
                                      ? const Color(0xFFF7931A)
                                      : const Color(0xFF00ff41),
                                  width: 2,
                                ),
                                boxShadow: filled
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFFF7931A)
                                              .withOpacity(0.5),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                            );
                          }),
                        ),
                      ),

                      // Error
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 18,
                        child: _errorMsg != null
                            ? Text(
                                _errorMsg!,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: Color(0xFFff4444),
                                  letterSpacing: 1,
                                ),
                              )
                            : null,
                      ),

                      const SizedBox(height: 24),

                      // Numpad
                      _buildNumpad(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumpad() {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];
    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((k) {
              if (k.isEmpty) return const SizedBox(width: 80, height: 64);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: _NumKey(
                  label: k,
                  onTap: () => k == '⌫' ? _onDelete() : _onKey(k),
                  isDelete: k == '⌫',
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

class _NumKey extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isDelete;

  const _NumKey({
    required this.label,
    required this.onTap,
    this.isDelete = false,
  });

  @override
  State<_NumKey> createState() => _NumKeyState();
}

class _NumKeyState extends State<_NumKey>
    with SingleTickerProviderStateMixin {
  late AnimationController _flashCtrl;
  late Animation<Color?> _flashAnim;

  @override
  void initState() {
    super.initState();
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,   // start at end (transparent) so initial state shows no flash
    );
    _flashAnim = ColorTween(
      begin: const Color(0xFFF7931A),
      end: Colors.transparent,
    ).animate(CurvedAnimation(parent: _flashCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _flashCtrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    _flashCtrl.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.isDelete
        ? const Color(0xFFff4444).withOpacity(0.06)
        : const Color(0xFF00ff41).withOpacity(0.05);
    final borderColor = widget.isDelete
        ? const Color(0xFFff4444).withOpacity(0.4)
        : const Color(0xFF00ff41).withOpacity(0.3);

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _flashAnim,
        builder: (_, child) => Container(
          width: 80,
          height: 64,
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              _flashAnim.value ?? Colors.transparent,
              baseColor,
            ),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: child,
        ),
        child: Center(
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: widget.isDelete ? 20 : 22,
              fontWeight: FontWeight.bold,
              color: widget.isDelete
                  ? const Color(0xFFff4444)
                  : const Color(0xFF00ff41),
              letterSpacing: 1,
            ),
          ),
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
