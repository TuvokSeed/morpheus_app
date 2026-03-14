import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PaymentException implements Exception {
  final String message;
  PaymentException(this.message);
  @override
  String toString() => message;
}

class LNDHubService {
  String? _baseUrl;
  String? _accessToken;
  String? _refreshToken;
  String? _login;
  String? _password;

  // ─── URL Parser ─────────────────────────────────────────────
  // Handles all known formats:
  //
  // Standard:
  //   lndhub://login:password@https://lndhub.io
  //   lndhub://login:password@https://lndhub.io/
  //
  // LNBits:
  //   lndhub://admin:password@https://sats.mobi/usersatoshi/ext/lndhub/ext
  //   lndhub://invoice:password@https://sats.mobi/usersatoshi/ext/lndhub/ext/
  //
  // Some hosts omit https:// in the URL part:
  //   lndhub://login:password@lndhub.io
  //
  Map<String, String> _parseLNDHubUrl(String rawUrl) {
    // Remove whitespace
    final url = rawUrl.trim();

    // Strip lndhub:// scheme
    final withoutScheme = url.startsWith('lndhub://')
        ? url.substring('lndhub://'.length)
        : url;

    // Find the LAST @ to split credentials from server
    // (important because passwords can contain @)
    final atIndex = withoutScheme.lastIndexOf('@');
    if (atIndex == -1) {
      throw PaymentException(
          'Invalid LNDHub URL: missing @ separator');
    }

    final credentialsPart = withoutScheme.substring(0, atIndex);
    var serverPart = withoutScheme.substring(atIndex + 1);

    // Parse login:password — split on FIRST colon only
    final colonIndex = credentialsPart.indexOf(':');
    if (colonIndex == -1) {
      throw PaymentException(
          'Invalid LNDHub URL: missing : in credentials');
    }
    final login = credentialsPart.substring(0, colonIndex);
    final password = credentialsPart.substring(colonIndex + 1);

    // Ensure server has https:// or http://
    if (!serverPart.startsWith('http://') &&
        !serverPart.startsWith('https://')) {
      serverPart = 'https://$serverPart';
    }

    // Remove trailing slash
    if (serverPart.endsWith('/')) {
      serverPart = serverPart.substring(0, serverPart.length - 1);
    }

    return {
      'login': login,
      'password': password,
      'url': serverPart,
    };
  }

  // ─── Connect ────────────────────────────────────────────────
  Future<bool> connect(String lndhubUrl) async {
    try {
      final parsed = _parseLNDHubUrl(lndhubUrl);
      _baseUrl = parsed['url'];
      _login = parsed['login'];
      _password = parsed['password'];

      // Try auth — with automatic fallback strategies
      final success = await _authenticate();
      if (!success) return false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', _accessToken!);
      await prefs.setString('refresh_token', _refreshToken ?? '');
      await prefs.setString('base_url', _baseUrl!);
      await prefs.setString('lndhub_url', lndhubUrl);
      await prefs.setString('login', _login!);
      await prefs.setString('password', _password!);

      return true;
    } on PaymentException {
      rethrow;
    } catch (e) {
      throw Exception('Connection failed: $e');
    }
  }

  // ─── Auth with multiple strategy fallbacks ──────────────────
  Future<bool> _authenticate() async {
    // Strategy 1: Standard LNDHub JSON auth POST /auth?type=auth
    try {
      final result = await _tryJsonAuth('$_baseUrl/auth?type=auth');
      if (result) return true;
    } catch (_) {}

    // Strategy 2: POST /auth (no query param — some LNBits versions)
    try {
      final result = await _tryJsonAuth('$_baseUrl/auth');
      if (result) return true;
    } catch (_) {}

    // Strategy 3: LNBits specific — POST /auth?type=auth
    // with different content type
    try {
      final result =
          await _tryFormAuth('$_baseUrl/auth?type=auth');
      if (result) return true;
    } catch (_) {}

    throw PaymentException(
        'Authentication failed — check your LNDHub URL and credentials');
  }

  Future<bool> _tryJsonAuth(String authUrl) async {
    final response = await http
        .post(
          Uri.parse(authUrl),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'login': _login,
            'password': _password,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return _parseAuthResponse(response.body);
    }
    return false;
  }

  Future<bool> _tryFormAuth(String authUrl) async {
    final response = await http
        .post(
          Uri.parse(authUrl),
          headers: {
            'Content-Type':
                'application/x-www-form-urlencoded',
            'Accept': 'application/json',
          },
          body: {
            'login': _login,
            'password': _password,
          },
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return _parseAuthResponse(response.body);
    }
    return false;
  }

  bool _parseAuthResponse(String body) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(body);
    } catch (_) {
      return false;
    }

    // Check for explicit error
    if (data['error'] == true || data['error'] == 1) {
      throw PaymentException(
          data['message'] as String? ?? 'Auth error');
    }

    // Extract tokens — handle both naming conventions
    final accessToken = data['access_token'] as String? ??
        data['accessToken'] as String? ??
        data['ACCESS_TOKEN'] as String?;

    final refreshToken = data['refresh_token'] as String? ??
        data['refreshToken'] as String? ??
        data['REFRESH_TOKEN'] as String?;

    if (accessToken == null || accessToken.isEmpty) {
      return false;
    }

    _accessToken = accessToken;
    _refreshToken = refreshToken;
    return true;
  }

  // ─── Load from storage ──────────────────────────────────────
  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
    _baseUrl = prefs.getString('base_url');
    _login = prefs.getString('login');
    _password = prefs.getString('password');
  }

  // ─── Refresh token ──────────────────────────────────────────
  Future<void> refreshAccessToken() async {
    // If we have refresh token, use it
    if (_refreshToken != null && _refreshToken!.isNotEmpty) {
      try {
        final response = await http
            .post(
              Uri.parse('$_baseUrl/auth?type=refresh'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode({
                'refresh_token': _refreshToken,
              }),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final newToken = data['access_token'] as String? ??
              data['accessToken'] as String?;
          if (newToken != null && newToken.isNotEmpty) {
            _accessToken = newToken;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('access_token', _accessToken!);
            return;
          }
        }
      } catch (_) {}
    }

    // Fallback: re-authenticate with stored credentials
    if (_login != null && _password != null) {
      await _authenticate();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', _accessToken!);
      if (_refreshToken != null) {
        await prefs.setString('refresh_token', _refreshToken!);
      }
      return;
    }

    throw Exception('Cannot refresh token — please reconnect');
  }

  // ─── Auth headers ───────────────────────────────────────────
  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $_accessToken',
      };

  // ─── Generic GET with 401 retry ─────────────────────────────
  Future<http.Response> _get(String path) async {
    var response = await http
        .get(Uri.parse('$_baseUrl$path'), headers: _authHeaders)
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 401) {
      await refreshAccessToken();
      response = await http
          .get(Uri.parse('$_baseUrl$path'), headers: _authHeaders)
          .timeout(const Duration(seconds: 20));
    }
    return response;
  }

  // ─── Generic POST with 401 retry ────────────────────────────
  Future<http.Response> _post(
      String path, Map<String, dynamic> body) async {
    var response = await http
        .post(
          Uri.parse('$_baseUrl$path'),
          headers: _authHeaders,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 401) {
      await refreshAccessToken();
      response = await http
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: _authHeaders,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
    }
    return response;
  }

  // ─── Get balance ────────────────────────────────────────────
  Future<int> getBalance() async {
    final response = await _get('/balance');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Standard LNDHub: { BTC: { AvailableBalance: int } }
      if (data['BTC'] != null) {
        return data['BTC']['AvailableBalance'] as int? ?? 0;
      }
      // Some implementations return flat: { balance: int }
      if (data['balance'] != null) {
        final bal = data['balance'];
        if (bal is int) return bal;
        if (bal is double) return bal.toInt();
        if (bal is String) return int.tryParse(bal) ?? 0;
      }
      return 0;
    }
    throw Exception(
        'Failed to get balance: ${response.statusCode}');
  }

  // ─── Create invoice ─────────────────────────────────────────
  Future<Map<String, dynamic>> createInvoice({
    required int amountSats,
    String memo = '',
  }) async {
    final response = await _post('/addinvoice', {
      'amt': amountSats,
      'memo': memo,
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['error'] == true || data['error'] == 1) {
        throw PaymentException(
            data['message'] ?? 'Failed to create invoice');
      }
      return data;
    }
    throw PaymentException(
        'Failed to create invoice: ${response.statusCode} ${response.body}');
  }

  // ─── Pay invoice ────────────────────────────────────────────
  Future<void> payInvoice(String paymentRequest) async {
    // Strip lightning: prefix if present
    final invoice = paymentRequest
        .trim()
        .replaceFirst(RegExp(r'^lightning:', caseSensitive: false), '');

    final response =
        await _post('/payinvoice', {'invoice': invoice});

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw PaymentException('Invalid response from server');
    }

    if (data['error'] == true || data['error'] == 1) {
      final msg = data['message'] as String? ??
          data['msg'] as String? ??
          'Payment failed';
      throw PaymentException(msg);
    }

    if (data['payment_error'] != null &&
        (data['payment_error'] as String).isNotEmpty) {
      throw PaymentException(data['payment_error'] as String);
    }

    if (response.statusCode != 200) {
      throw PaymentException(
          'Payment failed with status ${response.statusCode}');
    }

    final preimage = data['payment_preimage'] as String?;
    final payReq = data['pay_req'] as String?;
    if ((preimage == null || preimage.isEmpty) &&
        (payReq == null || payReq.isEmpty)) {
      if (data['payment_hash'] == null &&
          data['decoded'] == null) {
        throw PaymentException(
          data['message'] as String? ??
              'Payment did not complete',
        );
      }
    }
  }

  // ─── Get sent transactions ──────────────────────────────────
  Future<List<Map<String, dynamic>>> _getSentTransactions() async {
    final response = await _get('/gettxs');
    if (response.statusCode == 200) {
      final raw = jsonDecode(response.body);
      if (raw is! List) return [];
      return raw.map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        map['_direction'] = 'sent';
        map['_amount'] =
            (map['value'] as int? ?? map['amt'] as int? ?? 0)
                .abs();
        map['_timestamp'] = map['timestamp'] as int? ?? 0;
        map['_memo'] = map['memo'] as String? ??
            map['description'] as String? ??
            '';
        return map;
      }).toList();
    }
    return [];
  }

  // ─── Get received invoices ──────────────────────────────────
  Future<List<Map<String, dynamic>>>
      _getReceivedInvoices() async {
    final response = await _get('/getuserinvoices');
    if (response.statusCode == 200) {
      final raw = jsonDecode(response.body);
      if (raw is! List) return [];
      final result = <Map<String, dynamic>>[];
      for (final e in raw) {
        final map = Map<String, dynamic>.from(e as Map);
        final isPaid =
            map['ispaid'] == true || map['ispaid'] == 1;
        if (!isPaid) continue;
        map['_direction'] = 'received';
        map['_amount'] =
            (map['amt'] as int? ?? map['value'] as int? ?? 0)
                .abs();
        map['_timestamp'] = map['ispaid_at'] as int? ??
            map['paid_at'] as int? ??
            map['timestamp'] as int? ??
            0;
        map['_memo'] = map['memo'] as String? ??
            map['description'] as String? ??
            '';
        result.add(map);
      }
      return result;
    }
    return [];
  }

  // ─── Get all transactions merged + sorted ───────────────────
  Future<List<Map<String, dynamic>>> getAllTransactions() async {
    final results = await Future.wait([
      _getSentTransactions(),
      _getReceivedInvoices(),
    ]);

    final all = <Map<String, dynamic>>[
      ...results[0],
      ...results[1],
    ];

    all.sort((a, b) {
      final ta = a['_timestamp'] as int? ?? 0;
      final tb = b['_timestamp'] as int? ?? 0;
      return tb.compareTo(ta);
    });

    return all;
  }

  // ─── Get user invoices for polling ─────────────────────────
  Future<List<Map<String, dynamic>>> getUserInvoices() async {
    return _getReceivedInvoices();
  }

  // ─── Pay lightning address ──────────────────────────────────
  Future<String> payLightningAddress({
    required String address,
    required int amountSats,
    String comment = '',
  }) async {
    if (!address.contains('@')) {
      throw PaymentException('Invalid lightning address format');
    }
    final parts = address.split('@');
    final user = parts[0].toLowerCase();
    final domain = parts[1].toLowerCase();

    final lnurlUrl =
        'https://$domain/.well-known/lnurlp/$user';
    final metaResponse = await http
        .get(Uri.parse(lnurlUrl))
        .timeout(const Duration(seconds: 15));

    if (metaResponse.statusCode != 200) {
      throw PaymentException(
          'Could not reach $domain — address not found');
    }

    Map<String, dynamic> meta;
    try {
      meta = jsonDecode(metaResponse.body);
    } catch (_) {
      throw PaymentException('Invalid response from $domain');
    }

    if (meta['status'] == 'ERROR') {
      throw PaymentException(
          meta['reason'] as String? ?? 'LNURL error');
    }

    final minSendable =
        (meta['minSendable'] as int? ?? 1000) ~/ 1000;
    final maxSendable =
        (meta['maxSendable'] as int? ?? 1000000000) ~/ 1000;

    if (amountSats < minSendable) {
      throw PaymentException(
          'Minimum amount is $minSendable sats');
    }
    if (amountSats > maxSendable) {
      throw PaymentException(
          'Maximum amount is $maxSendable sats');
    }

    final callback = meta['callback'] as String;
    final amountMsats = amountSats * 1000;
    String callbackUrl = '$callback?amount=$amountMsats';

    if (comment.isNotEmpty) {
      final maxComment = meta['commentAllowed'] as int? ?? 0;
      if (maxComment > 0) {
        final trimmed = comment.length > maxComment
            ? comment.substring(0, maxComment)
            : comment;
        callbackUrl +=
            '&comment=${Uri.encodeComponent(trimmed)}';
      }
    }

    final invoiceResponse = await http
        .get(Uri.parse(callbackUrl))
        .timeout(const Duration(seconds: 15));

    if (invoiceResponse.statusCode != 200) {
      throw PaymentException(
          'Failed to get invoice from $domain');
    }

    Map<String, dynamic> invoiceData;
    try {
      invoiceData = jsonDecode(invoiceResponse.body);
    } catch (_) {
      throw PaymentException('Invalid invoice response');
    }

    if (invoiceData['status'] == 'ERROR') {
      throw PaymentException(
          invoiceData['reason'] as String? ?? 'Invoice error');
    }

    final bolt11 = invoiceData['pr'] as String?;
    if (bolt11 == null || bolt11.isEmpty) {
      throw PaymentException(
          'No invoice received from $domain');
    }

    await payInvoice(bolt11);
    return bolt11;
  }

  bool get isConnected =>
      _accessToken != null && _baseUrl != null;

  Future<void> disconnect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _accessToken = null;
    _refreshToken = null;
    _baseUrl = null;
    _login = null;
    _password = null;
  }
}
