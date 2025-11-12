import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';
// ⚠ ملاحظة: نحن نفترض أن كلاس Product في ملف '../models/product.dart' قد تم تحديثه ليحتوي على حقل 'storeId'.
// إذا لم تكوني قد عدلتيه، يجب أن تذهبي إلى ذلك الملف وتضيفي: final String storeId;

class CartItem {
  final Product product;
  // ✅ الحقول موجودة هنا كما كان لديك، لكن سنقوم بحسابها عبر getter
  // final double avgRating; // 🛑 تم حذف هذا السطر
  // final int ratingsCount; // 🛑 تم حذف هذا السطر
  int qty;

  // 💡 التعديل رقم 1: إزالة avgRating و ratingsCount من Constructor لـ CartItem.
  // تم إضافتهما كـ getters بدلاً من حقول لتجنب التكرار.
  CartItem({required this.product, this.qty = 1});

  // ✅ إضافة Getters للوصول إلى قيم التقييم بشكل آمن عبر Product
  double get avgRating => product.avgRating;
  int get ratingsCount => product.ratingsCount;

  double get lineTotal => product.price * qty;

  Map<String, dynamic> toJson() => {
    'qty': qty,
    'product': {
      'id': product.id,
      'title': product.title,
      'desc': product.desc,
      'price': product.price,
      'image': product.image,

      'sizes': product.sizes,
      // 🛑 التعديل رقم 1: حفظ storeId في الـ JSON للتخزين المحلي
      'storeId': product.storeId,
      // ✅ التعديل رقم 2: حفظ قيم التقييم المتوسطة في JSON
      'avgRating': product.avgRating,
      'ratingsCount': product.ratingsCount,
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

        sizes: (p['sizes'] is List)
            ? List<String>.from(p['sizes'] as List)
            : const <String>[],
        // 🛑 التعديل رقم 2: استرجاع storeId من الـ JSON المخزن محلياً
        storeId: (p['storeId'] ?? '').toString(),

        // ✅ التعديل رقم 3: قراءة avgRating و ratingsCount وتمريرهما لـ Product Constructor
        avgRating: (p['avgRating'] as num? ?? 0.0).toDouble(),
        ratingsCount: (p['ratingsCount'] as num? ?? 0).toInt(),

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
      // 💡 التعديل رقم 4: إنشاء CartItem جديد
      // تمرير الـ Product بالكامل (الذي يحتوي الآن على avgRating/ratingsCount)
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