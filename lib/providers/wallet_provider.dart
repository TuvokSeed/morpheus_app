import 'package:flutter/foundation.dart';
import '../services/lndhub_service.dart';
import '../services/bookmark_service.dart';

class WalletProvider extends ChangeNotifier {
  final LNDHubService _service = LNDHubService();
  final BookmarkService _bookmarkService = BookmarkService();

  int _balance = 0;
  List<Map<String, dynamic>> _transactions = [];
  List<LightningBookmark> _bookmarks = [];
  bool _isLoading = false;
  String? _error;
  bool _isConnected = false;

  int get balance => _balance;
  List<Map<String, dynamic>> get transactions => _transactions;
  List<LightningBookmark> get bookmarks => _bookmarks;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isConnected => _isConnected;
  LNDHubService get service => _service;

  Future<void> initialize() async {
    await _service.loadFromStorage();
    _isConnected = _service.isConnected;
    await loadBookmarks();
    if (_isConnected) await refreshAll();
    notifyListeners();
  }

  Future<bool> connect(String lndhubUrl) async {
    _setLoading(true);
    try {
      _isConnected = await _service.connect(lndhubUrl);
      if (_isConnected) await refreshAll();
      return _isConnected;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshAll() async {
    _setLoading(true);
    try {
      // Fetch balance and both sent+received in parallel
      final results = await Future.wait([
        _service.getBalance(),
        _service.getAllTransactions(),
      ]);
      _balance = results[0] as int;
      _transactions =
          results[1] as List<Map<String, dynamic>>;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> createInvoice(
      int sats, String memo) async {
    return await _service.createInvoice(
        amountSats: sats, memo: memo);
  }

  Future<String?> payInvoice(String invoice) async {
    _setLoading(true);
    try {
      await _service.payInvoice(invoice);
      await refreshAll();
      return null;
    } on PaymentException catch (e) {
      _error = e.message;
      _setLoading(false);
      notifyListeners();
      return e.message;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      _error = msg;
      _setLoading(false);
      notifyListeners();
      return msg;
    } finally {
      if (_isLoading) _setLoading(false);
    }
  }

  Future<String?> payLightningAddress({
    required String address,
    required int amountSats,
    String comment = '',
  }) async {
    _setLoading(true);
    try {
      await _service.payLightningAddress(
        address: address,
        amountSats: amountSats,
        comment: comment,
      );
      await refreshAll();
      return null;
    } on PaymentException catch (e) {
      _error = e.message;
      _setLoading(false);
      notifyListeners();
      return e.message;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      _error = msg;
      _setLoading(false);
      notifyListeners();
      return msg;
    } finally {
      if (_isLoading) _setLoading(false);
    }
  }

  Future<void> loadBookmarks() async {
    _bookmarks = await _bookmarkService.getAll();
    notifyListeners();
  }

  Future<void> addBookmark(String label, String address) async {
    final bookmark = LightningBookmark(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      label: label,
      address: address,
      createdAt: DateTime.now(),
    );
    await _bookmarkService.add(bookmark);
    await loadBookmarks();
  }

  Future<void> deleteBookmark(String id) async {
    await _bookmarkService.delete(id);
    await loadBookmarks();
  }

  Future<void> disconnect() async {
    await _service.disconnect();
    _isConnected = false;
    _balance = 0;
    _transactions = [];
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
