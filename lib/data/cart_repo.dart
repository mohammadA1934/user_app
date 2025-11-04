import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';

class CartItem {
  final Product product;
  int qty;

  CartItem({required this.product, this.qty = 1});

  double get lineTotal => product.price * qty;

  Map<String, dynamic> toJson() => {
    'qty': qty,
    'product': {
      'id': product.id,
      'title': product.title,
      'desc': product.desc,
      'price': product.price,
      'image': product.image,
      'rating': product.rating,
      'reviews': product.reviews,
      'sizes': product.sizes,
    },
  };

  static CartItem fromJson(Map<String, dynamic> m) {
    final p = m['product'] as Map<String, dynamic>? ?? const {};
    return CartItem(
      product: Product(
        id: (p['id'] ?? '').toString(),
        title: (p['title'] ?? '').toString(),
        desc: (p['desc'] ?? '').toString(),
        price: (p['price'] is num)
            ? (p['price'] as num).toDouble()
            : double.tryParse('${p['price']}') ?? 0.0,
        image: (p['image'] ?? '').toString(),
        rating: (p['rating'] is num) ? (p['rating'] as num).toDouble() : 0.0,
        reviews: (p['reviews'] is num) ? (p['reviews'] as num).toInt() : 0,
        sizes: (p['sizes'] is List)
            ? List<String>.from(p['sizes'] as List)
            : const <String>[],
      ),
      qty: (m['qty'] is num) ? (m['qty'] as num).toInt() : 1,
    );
  }
}

class CartRepo extends ChangeNotifier {
  CartRepo._();
  static final CartRepo instance = CartRepo._();

  static const _prefsKey = 'cart_items_v2';

  // key = product.id
  final Map<String, CartItem> _items = {};
  bool _loaded = false;

  /// استدعِ هذه مرة واحدة (مثلاً في main) لتحميل السلة من التخزين.
  Future<void> init() async {
    if (_loaded) return;
    _loaded = true;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final List list = jsonDecode(raw) as List;
      _items.clear();
      for (final e in list) {
        final item = CartItem.fromJson(Map<String, dynamic>.from(e));
        _items[item.product.id] = item;
      }
      notifyListeners();
    } catch (_) {
      // تجاهل أي بيانات تالفة
    }
  }

  List<CartItem> get items => _items.values.toList(growable: false);
  bool contains(String productId) => _items.containsKey(productId);

  void add(Product p, {int qty = 1}) {
    final it = _items[p.id];
    if (it != null) {
      it.qty += qty;
    } else {
      _items[p.id] = CartItem(product: p, qty: qty);
    }
    _save();
  }

  void setQty(String productId, int qty) {
    final it = _items[productId];
    if (it == null) return;
    it.qty = qty.clamp(1, 9999);
    _save();
  }

  void increment(String productId) {
    final it = _items[productId];
    if (it == null) return;
    it.qty++;
    _save();
  }

  void decrement(String productId) {
    final it = _items[productId];
    if (it == null) return;
    if (it.qty > 1) {
      it.qty--;
    } else {
      _items.remove(productId);
    }
    _save();
  }

  void remove(String productId) {
    _items.remove(productId);
    _save();
  }

  void clear() {
    _items.clear();
    _save();
  }

  int get totalQty => _items.values.fold(0, (a, b) => a + b.qty);
  double get totalAmount =>
      _items.values.fold(0.0, (a, b) => a + b.lineTotal);

  // ------- تخزين محلي -------
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _items.values.map((e) => e.toJson()).toList();
    await prefs.setString(_prefsKey, jsonEncode(data));
    notifyListeners();
  }
}
