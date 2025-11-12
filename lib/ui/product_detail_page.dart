import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../data/favorites_repo.dart';
import '../data/cart_repo.dart';

import 'home_page.dart';
import 'wishlist_page.dart';
import 'cart_page.dart';
import 'my_orders_page.dart';
import 'profile_settings_page.dart';
import 'rating_display.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.product});
  final Product product;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  static const Color kPrimary = Color(0xFF34D399);
  static const Color kText = Color(0xFF222222);
  static const Color kHint = Color(0xFF9AA0A6);
  static const Color kBorder = Color(0xFFE5E7EB);

  bool _isValidHttpUrl(String? s) {
    if (s == null || s.isEmpty) return false;
    final u = Uri.tryParse(s);
    return u != null && (u.scheme == 'http' || u.scheme == 'https');
  }

  // 💡 الحل البديل: دالة مساعدة لتهيئة المنتج من الـ Map
  Product _productFromMap(Map<String, dynamic> m, String id) {
    // 1. قراءة البيانات الجديدة المخزنة في Firestore
    final firestoreAvgRating = (m['avgRating'] as num? ?? 0.0).toDouble();
    final firestoreRatingsCount = (m['ratingsCount'] as num? ?? 0).toInt();

    // 2. استخدام البيانات الجديدة لتهيئة الـ constructor
    return Product(
      id: id,
      title: (m['name'] ?? 'Product').toString(),
      desc: (m['description'] ?? m['desc'] ?? '').toString(),
      price: (m['price'] as num? ?? double.tryParse('${m['price']}') ?? 0.0).toDouble(),
      image: (m['imageUrl'] ?? m['image'] ?? '').toString(),

      // ✅ تعيين الحقول القديمة بالقيم الجديدة لضمان التوافق (مثل CartPage)


      // ✅ الحقول الجديدة
      avgRating: firestoreAvgRating,
      ratingsCount: firestoreRatingsCount,

      storeId: (m['storeId'] ?? '').toString(),
      // لا نحتاج لتعيين sizes يدوياً إذا كان الكلاس يحتوي على قيمة افتراضية
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: .3,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: kText),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          p.title,
          style: const TextStyle(color: kText, fontWeight: FontWeight.w700),
        ),
        actions: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileSettingsPage()),
              );
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: kBorder,
                child: Icon(Icons.person, size: 18, color: kText),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),

      bottomNavigationBar: _BottomBarWithActions(product: widget.product),

      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            // الصورة (مع معالجة وصلة غير صحيحة)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: _isValidHttpUrl(p.image)
                    ? Image.network(
                  p.image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: Colors.grey.shade200),
                )
                    : Container(color: Colors.grey.shade200),
              ),
            ),
            const SizedBox(height: 12),

            // مكان المقاسات السابق → تقييم على اليسار + السعر على اليمين
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 💡 إضافة RatingDisplay لعرض التقييم
                RatingDisplay(
                  avgRating: p.avgRating,
                  ratingsCount: p.ratingsCount,
                  starSize: 22,
                  textSize: 18,
                ),

                const Spacer(),
                // السعر
                Text(
                  '${p.price.toStringAsFixed(2)} JD',
                  style: const TextStyle(
                    color: kText,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            const Text('Product Details',
                style: TextStyle(
                    color: kText, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              p.desc,
              style: const TextStyle(color: Colors.black87, height: 1.35),
            ),

            const SizedBox(height: 20),

            const Text('Similar To',
                style: TextStyle(
                    color: kText, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _similarFromSameStore(p),
          ],
        ),
      ),
    );
  }

  /// يجلب منتجًا آخر من نفس المتجر باستثناء المنتج الحالي
  Widget _similarFromSameStore(Product current) {
    final products = FirebaseFirestore.instance.collection('products');

    // 1) اقرأ المستند الحالي لمعرفة storeId
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: products.doc(current.id).get(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _similarPlaceholder();
        }
        if (!snap.hasData || !snap.data!.exists) {
          return _similarPlaceholder();
        }
        final storeId = (snap.data!.data()?['storeId'] ?? '').toString();
        if (storeId.isEmpty) return _similarPlaceholder();

        // 2) احضر منتجًا آخر من نفس المتجر غير الحالي
        return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
          future: products
              .where('storeId', isEqualTo: storeId)
              .where(FieldPath.documentId, isNotEqualTo: current.id)
              .orderBy('createdAt', descending: true)
              .limit(1)
              .get(),
          builder: (context, s2) {
            if (s2.hasError || !s2.hasData || s2.data!.docs.isEmpty) {
              return _similarPlaceholder();
            }
            final d = s2.data!.docs.first;
            final m = d.data();

            // 🛑 استخدام الدالة المساعدة الجديدة بدلاً من Product.fromMap
            final other = _productFromMap(m, d.id);

            return _similarSingle(other);
          },
        );
      },
    );
  }

  Widget _similarPlaceholder() {
    return Container(
      height: 110,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: const Text('No similar items'),
    );
  }

  Widget _similarSingle(Product p) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => ProductDetailPage(product: p)),
          );
        },
        child: Row(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: _imageOrPlaceholder(p.image),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    p.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                    const TextStyle(fontWeight: FontWeight.w700, color: kText),
                  ),
                  const SizedBox(height: 4),
                  // 💡 عرض التقييم للمنتج المشابه
                  RatingDisplay(
                    avgRating: p.avgRating,
                    ratingsCount: p.ratingsCount,
                    starSize: 14,
                    textSize: 12,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }

  Widget _imageOrPlaceholder(String url) {
    return _isValidHttpUrl(url)
        ? Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          Container(color: Colors.grey.shade200),
    )
        : Container(color: Colors.grey.shade200);
  }

  static String _formatCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

/// يجمع بين صف أزرار (Add to Cart / Add to Wishlist) + Bottom Nav المطلوب
class _BottomBarWithActions extends StatelessWidget {
  const _BottomBarWithActions({required this.product});
  final Product product;

  static const kPrimary = _ProductDetailPageState.kPrimary;
  static const kBorder = _ProductDetailPageState.kBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- الأزرار ---
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        CartRepo.instance.add(product);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const CartPage()),
                        );
                      },
                      icon: const Icon(Icons.shopping_cart_outlined),
                      label: const Text('Add To Cart'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        FavoritesRepo.instance.add(product);
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                              builder: (_) => const WishlistPage()),
                        );
                      },
                      icon: const Icon(Icons.favorite),
                      label: const Text('Add To Wishlist'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Divider(height: 1),

            // --- الـ Bottom Nav ---
            SizedBox(
              height: 68,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _navItem(
                        context,
                        icon: Icons.home_rounded,
                        label: 'Home',
                        onTap: () => Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const HomePage()),
                              (r) => false,
                        ),
                      ),
                      _navItem(
                        context,
                        icon: Icons.favorite_border_rounded,
                        label: 'Wishlist',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const WishlistPage()),
                        ),
                      ),
                      const SizedBox(width: 56),
                      _navItem(
                        context,
                        icon: Icons.inventory_2_outlined,
                        label: 'My Orders',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const MyOrdersPage()),
                        ),
                      ),
                      _navItem(
                        context,
                        icon: Icons.settings_outlined,
                        label: 'Setting',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ProfileSettingsPage()),
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    bottom: 8,
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CartPage()),
                      ),
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: kPrimary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: kPrimary.withOpacity(.25),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.shopping_cart_rounded,
                            color: Colors.white, size: 26),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context,
      {required IconData icon,
        required String label,
        required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black87),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}