// lib/data/repositories/firestore_repos.dart
import 'package:cloud_firestore/cloud_firestore.dart';

final db = FirebaseFirestore.instance;

class StoreRepo {
  static CollectionReference get _col => db.collection('stores');

  static Future<void> createStore({
    required String id,
    required String name,
    required List<String> categories,
    String? logoUrl,
    double rating = 0,
    bool isOpen = false,
    bool isActive = true,
  }) async {
    await _col.doc(id).set({
      'name': name,
      'categories': categories,
      'logoUrl': logoUrl,
      'rating': rating,
      'isOpen': isOpen,
      'isActive': isActive,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

class ProductRepo {
  static CollectionReference get _col => db.collection('products');

  static Future<String> createProduct({
    required String storeId,
    required String name,
    required String category,
    required num price,
    List<String> imageUrls = const [],
    double rating = 0,
    bool inStock = true,
    bool isActive = true,
  }) async {
    final doc = await _col.add({
      'storeId': storeId,
      'name': name,
      'category': category,
      'price': price,
      'imageUrls': imageUrls,
      'rating': rating,
      'inStock': inStock,
      'isActive': isActive,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }
}

class UserRepo {
  static DocumentReference userDoc(String uid) => db.collection('users').doc(uid);

  static Future<void> ensureUserDoc(String uid, String email) async {
    await userDoc(uid).set({
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> addToWishlist(String uid, String productId) async {
    await userDoc(uid).collection('wishlist').doc(productId).set({
      'productRef': db.collection('products').doc(productId),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
