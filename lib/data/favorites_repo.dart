import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';

/// مخزن المفضلة مع حفظ محلي (يبقى بعد إعادة التشغيل)
class FavoritesRepo extends ChangeNotifier {
  FavoritesRepo._() {
    _load(); // تحميل القائمة المحفوظة عند إنشاء الريبو
  }
  static final FavoritesRepo instance = FavoritesRepo._();

  static const _storageKey = 'wishlist_v1';

  final Map<String, Product> _items = {};

  List<Product> get items => _items.values.toList(growable: false);
  bool isFav(String id) => _items.containsKey(id);

  // ======== Persistence ========
  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) return;

      final List list = jsonDecode(raw) as List;
      _items.clear();
      for (final e in list) {
        final map = e as Map<String, dynamic>;
        final p = Product(
          id: (map['id'] ?? '') as String,
          title: (map['title'] ?? 'Product') as String,
          desc: (map['desc'] ?? '') as String,
          price: (map['price'] is num) ? (map['price'] as num).toDouble() : 0.0,
          image: (map['image'] ?? '') as String,

          storeId: (map['storeId'] ?? '').toString(),
            avgRating: (map['avgRating'] as num? ?? 0.0).toDouble(),
            // 💡 جلب عدد مرات التقييم
            ratingsCount: (map['ratingsCount'] as num? ?? 0).toInt(),
        );
        _items[p.id] = p;
      }
      notifyListeners();
    } catch (_) {
      // تجاهل أي خطأ في التحميل
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _items.values
        .map((p) => {
      'id': p.id,
      'title': p.title,
      'desc': p.desc,
      'price': p.price,
      'image': p.image,

    })
        .toList();
    await prefs.setString(_storageKey, jsonEncode(list));
  }
  // =============================

  void add(Product p) {
    _items[p.id] = p;
    _save();
    notifyListeners();
  }

  void remove(String id) {
    _items.remove(id);
    _save();
    notifyListeners();
  }

  void toggle(Product p) {
    if (isFav(p.id)) {
      _items.remove(p.id);
    } else {
      _items[p.id] = p;
    }
    _save();
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _save();
    notifyListeners();
  }
}
