import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LightningBookmark {
  final String id;
  final String label;
  final String address; // user@domain.com
  final DateTime createdAt;

  LightningBookmark({
    required this.id,
    required this.label,
    required this.address,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'address': address,
        'createdAt': createdAt.toIso8601String(),
      };

  factory LightningBookmark.fromJson(Map<String, dynamic> json) =>
      LightningBookmark(
        id: json['id'] as String,
        label: json['label'] as String,
        address: json['address'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class BookmarkService {
  static const _key = 'lightning_bookmarks';

  Future<List<LightningBookmark>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => LightningBookmark.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> add(LightningBookmark bookmark) async {
    final all = await getAll();
    all.add(bookmark);
    await _save(all);
  }

  Future<void> delete(String id) async {
    final all = await getAll();
    all.removeWhere((b) => b.id == id);
    await _save(all);
  }

  Future<void> _save(List<LightningBookmark> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(list.map((e) => e.toJson()).toList()));
  }
}
