import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// صفحات/مزايا نحتاجها للتنقل والإضافة
import 'home_page.dart';
import 'wishlist_page.dart';
import 'cart_page.dart';
import 'my_orders_page.dart';
import 'profile_settings_page.dart';

import '../models/product.dart';
import '../data/cart_repo.dart';
import 'product_detail_page.dart';

import '../data/favorites_repo.dart';


class StorePage extends StatelessWidget {
  const StorePage({
    super.key,
    required this.storeId,   // ← معرف المتجر (هو نفسه id وثيقة shops)
    required this.storeName,
    this.storeLogo,
  });

  final String storeId;
  final String storeName;
  final String? storeLogo;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF34D399);
    const textDark = Color(0xFF222222);
    const hint = Color(0xFF9AA0A6);
    const border = Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: Colors.white,

      // AppBar
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.3,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Shoppinest',
          style: TextStyle(
            color: green,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileSettingsPage()),
              );
            },
            child: CircleAvatar(
              radius: 16,
              backgroundColor: border,
              child: const Icon(Icons.person, color: textDark, size: 18),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),

      // شريط سفلي تفاعلي مثل التصميم (زر cart دائري بالوسط)
      bottomNavigationBar: const _BottomBar(),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SearchBar(),
              const SizedBox(height: 12),

              // سطر اسم المتجر + أيقونات
              Row(
                children: [
                  if (storeLogo != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: CircleAvatar(
                        backgroundColor: border,
                        backgroundImage: NetworkImage(storeLogo!),
                        radius: 14,
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Icon(Icons.local_cafe, color: textDark),
                    ),
                  Expanded(
                    child: Text(
                      storeName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textDark,
                      ),
                    ),
                  ),
                  // أيقونة الرسالة → محادثة حقيقية
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _ChatScreen(
                            storeId: storeId,
                            storeName: storeName,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline, color: textDark),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.tune, color: textDark),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // شبكة المنتجات (حقيقية من Firestore) — باستخدام storeId مباشرة
              Expanded(
                child: _StoreProductsGrid(storeId: storeId),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// تعرض منتجات المتجر مباشرة بتمرير storeId (id وثيقة shops)
class _StoreProductsGrid extends StatelessWidget {
  const _StoreProductsGrid({required this.storeId});

  final String storeId;

  @override
  Widget build(BuildContext context) {
    final products = FirebaseFirestore.instance
        .collection('products')
        .where('storeId', isEqualTo: storeId)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: products,
      builder: (context, prodSnap) {
        if (prodSnap.hasError) {
          return _err(prodSnap.error);
        }
        if (prodSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = prodSnap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No products to show'));
        }

        return GridView.builder(
          padding: EdgeInsets.zero,
          itemCount: docs.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            // ارتفاع البطاقة مناسب لتفادي الـ overflow
            childAspectRatio: .66,
          ),
          itemBuilder: (context, index) {
            final d = docs[index].data();
            // تحويل وثيقة Firestore -> Product موديل التطبيق
            final product = Product(
              id: docs[index].id,
              title: (d['name'] ?? 'Product').toString(),
              desc: (d['description'] ?? d['desc'] ?? '').toString(),
              price: (d['price'] is num)
                  ? (d['price'] as num).toDouble()
                  : double.tryParse('${d['price']}') ?? 0,
              image: (d['imageUrl'] ?? d['image'] ?? '').toString(),
              rating: (d['rating'] is num)
                  ? (d['rating'] as num).toDouble()
                  : 4.6,
              reviews: d['reviews'] is num ? (d['reviews'] as num).toInt() : 0,
            );

            return _ProductCardUI(
              product: product,
              onOpenDetails: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailPage(product: product),
                  ),
                );
              },
              onCart: () {
                CartRepo.instance.add(product);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartPage()),
                );
              },
              // ✅ هنا التعديل الوحيد: القلب يضيف للـ FavoritesRepo فقط
              onWishlist: () {
                FavoritesRepo.instance.add(product);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Added to Wishlist')),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _err(Object? e) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        'Error: $e',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.red),
      ),
    ),
  );
}

/// شريط سفلي خاص بالمتجر (Home/Wishlist/Cart/My Orders/Setting)
class _BottomBar extends StatelessWidget {
  const _BottomBar();

  static const kPrimary = Color(0xFF34D399);
  static const kBorder = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _barItem(
                context,
                icon: Icons.home_rounded,
                label: 'Home',
                onTap: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomePage()),
                      (r) => false,
                ),
                selected: false,
              ),
              _barItem(
                context,
                icon: Icons.favorite_border_rounded,
                label: 'Wishlist',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WishlistPage()),
                ),
                selected: false,
              ),
              const SizedBox(width: 56), // فراغ للزر الدائري
              _barItem(
                context,
                icon: Icons.inventory_2_outlined,
                label: 'My Orders',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyOrdersPage()),
                ),
                selected: false,
              ),
              _barItem(
                context,
                icon: Icons.settings_outlined,
                label: 'Setting',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ProfileSettingsPage()),
                ),
                selected: false,
              ),
            ],
          ),

          // زر العربة الدائري بالوسط
          Positioned(
            bottom: 8,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartPage()),
              ),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: kBorder),
                ),
                child: const Icon(
                  Icons.shopping_cart_rounded,
                  color: kPrimary,
                  size: 26,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barItem(
      BuildContext context, {
        required IconData icon,
        required String label,
        required VoidCallback onTap,
        bool selected = false,
      }) {
    final color = selected ? kPrimary : Colors.black54;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// بطاقة المنتج كما في التصميم + التنقل إلى Wishlist/Cart
class _ProductCardUI extends StatelessWidget {
  const _ProductCardUI({
    required this.product,
    required this.onOpenDetails,
    required this.onCart,
    required this.onWishlist,
  });

  final Product product;
  final VoidCallback onOpenDetails;
  final VoidCallback onCart;
  final VoidCallback onWishlist;

  static const textDark = Color(0xFF222222);
  static const hint = Color(0xFF9AA0A6);
  static const border = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: .5,
      child: InkWell(
        onTap: onOpenDetails,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // صورة مرنة تمنع Overflow
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: (product.image.isNotEmpty)
                    ? Image.network(product.image, fit: BoxFit.cover)
                    : Container(color: border),
              ),
            ),

            // معلومات
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: textDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: hint,
                      fontSize: 12.2,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${product.price.toStringAsFixed(2)} JD',
                    style: const TextStyle(
                      color: textDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 2),
                      Text(
                        product.rating.toStringAsFixed(1),
                        style: const TextStyle(color: textDark, fontSize: 12.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '• ${_formatCount(product.reviews)}',
                        style: const TextStyle(color: hint, fontSize: 12.5),
                      ),
                      const Spacer(),
                      // القلب → Wishlist (الاستدعاء يُمرَّر من الأعلى)
                      IconButton(
                        onPressed: onWishlist,
                        icon: const Icon(Icons.favorite_border, size: 18),
                        color: hint,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 6),
                      // السلة → يضيف ويفتح Cart
                      IconButton(
                        onPressed: onCart,
                        icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                        color: Color(0xFF34D399),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

/// مستودع Wishlist بسيط داخل الصفحة (بدون تعديل ملفات أخرى)
class _WishlistRepo {
  _WishlistRepo._();
  static final _WishlistRepo instance = _WishlistRepo._();
  final List<Product> _items = [];
  void add(Product p) {
    if (_items.indexWhere((e) => e.id == p.id) == -1) {
      _items.add(p);
    }
  }
  List<Product> get items => List.unmodifiable(_items);
}

/// شاشة محادثة حقيقية – تحفظ وتقرأ من Firestore
class _ChatScreen extends StatefulWidget {
  const _ChatScreen({required this.storeId, required this.storeName});
  final String storeId;
  final String storeName;

  @override
  State<_ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<_ChatScreen> {
  final _txt = TextEditingController();
  String? _convId; // conversations/{cid}

  @override
  void initState() {
    super.initState();
    _ensureConversation();
  }

  Future<void> _ensureConversation() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // نبحث إن كان هناك محادثة بين هذا الزبون وهذا المتجر
    final convs = FirebaseFirestore.instance.collection('conversations');
    final q = await convs
        .where('storeId', isEqualTo: widget.storeId)
        .where('customerUid', isEqualTo: uid)
        .limit(1)
        .get();

    if (q.docs.isNotEmpty) {
      setState(() => _convId = q.docs.first.id);
      return;
    }

    // إنشاء محادثة جديدة
    final doc = await convs.add({
      'storeId': widget.storeId,
      'customerUid': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageText': '',
      'unreadForStore': true,
      'unreadForCustomer': false,
    });
    setState(() => _convId = doc.id);
  }

  Future<void> _send() async {
    final text = _txt.text.trim();
    if (text.isEmpty || _convId == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final msgs = FirebaseFirestore.instance
        .collection('conversations')
        .doc(_convId)
        .collection('msgs');

    await msgs.add({
      'sender': 'customer',
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // تحديث بيانات المحادثة
    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(_convId)
        .update({
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageText': text,
      'unreadForStore': true,
      'unreadForCustomer': false,
    });

    _txt.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat • ${widget.storeName}')),
      body: Column(
        children: [
          Expanded(
            child: (_convId == null)
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('conversations')
                  .doc(_convId)
                  .collection('msgs')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Error: ${snap.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }
                final msgs = snap.data?.docs ?? [];
                if (msgs.isEmpty) {
                  return const Center(
                      child: Text('Start chatting with the store…'));
                }
                final uid = FirebaseAuth.instance.currentUser?.uid;
                return ListView.builder(
                  reverse: true,
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final m = msgs[i].data();
                    final me = m['sender'] == 'customer';
                    return Align(
                      alignment:
                      me ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: me
                              ? const Color(0xFFE6FFF6)
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text((m['text'] ?? '').toString()),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _txt,
                      decoration: const InputDecoration(
                        hintText: 'Type a message…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _send,
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
