import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/favorites_repo.dart';
import '../models/product.dart';

import 'home_page.dart';
import 'product_detail_page.dart';
import 'cart_page.dart';
import 'my_orders_page.dart';
import 'profile_settings_page.dart';

import '../data/cart_repo.dart';
import 'rating_display.dart';

// ==========================================================
// 🛑 الكلاس الرئيسي: WishlistPage (Stateless -> StatefulWidget)
// ==========================================================

class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key});

  static const kPrimary = Color(0xFF34D399);
  static const kTextDark = Color(0xFF222222);
  static const kHint = Color(0xFF9AA0A6);
  static const kBorder = Color(0xFFE5E7EB);

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  User? _user;
  String? _userPhotoUrl;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadUserProfile() async {
    _user = _auth.currentUser;
    if (_user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_user!.uid)
            .get();

        if (doc.exists) {
          final data = doc.data();
          if (mounted) {
            setState(() {
              _userPhotoUrl = data?['photoUrl'] as String?;
            });
          }
        }
      } catch (e) {
        debugPrint('Error loading user profile: $e');
      }
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: const _BottomNav(currentIndex: 1),
      body: SafeArea(
        child: Column(
          children: [
            _header(context),
            _searchBox(),
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: FavoritesRepo.instance,
              builder: (_, __) {
                // عدد العناصر في القائمة الحقيقية (قبل الفلترة)
                final count = FavoritesRepo.instance.items.length;
                return _titleRow(count);
              },
            ),
            const Divider(height: 16),
            Expanded(
              child: AnimatedBuilder(
                animation: FavoritesRepo.instance,
                builder: (_, __) {
                  // هنا يتم جلب IDs المنتجات من قائمة الأمنيات
                  final allItems = FavoritesRepo.instance.items; // List<Product>

                  // 🛑 تطبيق فلترة البحث على الـ Product Objects
                  final filteredItems = allItems.where((product) {
                    final title = product.title.toLowerCase();
                    return title.contains(_searchQuery);
                  }).toList();

                  if (filteredItems.isEmpty) {
                    return Center(
                      child: Text(
                        _searchQuery.isEmpty
                            ? 'No items in wishlist yet'
                            : 'No results found for "$_searchQuery"',
                        style: const TextStyle(color: WishlistPage.kHint),
                      ),
                    );
                  }

                  // 💡 نقوم بتمرير IDs المنتجات فقط إلى _ProductCard
                  final productIds = filteredItems.map((e) => e.id).toList();

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: GridView.builder(
                      itemCount: productIds.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: .70,
                      ),
                      // 🛑 التعديل الأهم: تمرير ID المنتج بدلاً من الكائن الكامل
                      itemBuilder: (_, i) => _ProductCard(productId: productIds[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 6),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          const Text(
            'Shoppinest',
            style: TextStyle(
              color: WishlistPage.kPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const Spacer(),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileSettingsPage()),
              ).then((_) {
                _loadUserProfile();
              });
            },
            child: CircleAvatar(
              radius: 18,
              backgroundColor: WishlistPage.kPrimary.withOpacity(0.15),
              backgroundImage: (_userPhotoUrl != null && _userPhotoUrl!.isNotEmpty)
                  ? NetworkImage(_userPhotoUrl!) as ImageProvider<Object>
                  : null,
              child: (_userPhotoUrl == null || _userPhotoUrl!.isEmpty)
                  ? const Icon(Icons.person, color: WishlistPage.kPrimary)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBox() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 44,
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search any Product..',
            prefixIcon: const Icon(Icons.search_rounded, color: WishlistPage.kHint),
            hintStyle: const TextStyle(color: WishlistPage.kHint),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: WishlistPage.kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
              const BorderSide(color: WishlistPage.kPrimary, width: 1.4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _titleRow(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Text(
            '$count Items',
            style: const TextStyle(
              color: WishlistPage.kTextDark,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

// ==========================================================
// 🛑 كلاس _ProductCard: يستخدم StreamBuilder للتحديث التلقائي
// ==========================================================

class _ProductCard extends StatelessWidget {
  // 🛑 تم تغيير نوع المدخل من Product إلى String (ID)
  const _ProductCard({required this.productId});
  final String productId;

  static const textDark = WishlistPage.kTextDark;
  static const green = WishlistPage.kPrimary;
  static const hint = WishlistPage.kHint;
  static const border = WishlistPage.kBorder;

  @override
  Widget build(BuildContext context) {
    // 💡 استخدام StreamBuilder للاستماع لتغييرات المنتج من Firestore
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .doc(productId) // الاستماع للمنتج المحدد بالـ ID
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard();
        }

        // التعامل مع حالة عدم وجود المنتج (ربما تم حذفه من قبل المتجر)
        if (!snapshot.hasData || !snapshot.data!.exists) {
          // يمكن هنا إزالة العنصر من القائمة مباشرة، أو تركه كرسالة خطأ مؤقتة
          // بما أن FavoritesRepo يعتمد على الذاكرة، سنعتبره محذوفاً ونزيله
          WidgetsBinding.instance.addPostFrameCallback((_) {
            FavoritesRepo.instance.remove(productId);
          });
          return _buildDeletedCard();
        }

        final d = snapshot.data!.data()!;

        // 💡 إنشاء كائن Product من البيانات الحية
        final liveProduct = Product(
          id: snapshot.data!.id,
          title: (d['name'] ?? 'Product').toString(),
          desc: (d['description'] ?? '').toString(),
          price: (d['price'] is num)
              ? (d['price'] as num).toDouble()
              : double.tryParse('${d['price']}') ?? 0,
          image: (d['imageUrl'] ?? d['image'] ?? '').toString(),
          storeId: (d['storeId'] ?? '').toString(),
          avgRating: (d['avgRating'] as num? ?? 0.0).toDouble(),
          ratingsCount: (d['ratingsCount'] as num? ?? 0).toInt(),
        );

        // بناء البطاقة باستخدام البيانات الحية (liveProduct)
        return Material(
          color: Colors.white,
          elevation: .5,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProductDetailPage(product: liveProduct),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ الصورة (تحديث حي)
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: (liveProduct.image.isNotEmpty)
                          ? Image.network(
                        liveProduct.image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: Colors.grey.shade200),
                      )
                          : Container(color: Colors.grey.shade200),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // ✅ العنوان (تحديث حي)
                  Text(
                    liveProduct.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // 💡 السعر والتقييم (تحديث حي)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${liveProduct.price.toStringAsFixed(2)} JD',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      RatingDisplay(
                        avgRating: liveProduct.avgRating,
                        ratingsCount: liveProduct.ratingsCount,
                        starSize: 14,
                        textSize: 12.5,
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // سطر الأيقونات
                  Row(
                    children: [
                      const Spacer(),
                      // ✅ حذف من الـ Wishlist (يستخدم الـ ID الحي)
                      IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.delete_outline_rounded),
                        // 💡 حذف المنتج من FavoritesRepo باستخدام الـ ID
                        onPressed: () => FavoritesRepo.instance.remove(liveProduct.id),
                      ),
                      const SizedBox(width: 6),
                      // ✅ نقل إلى السلة ثم فتح صفحة السلة
                      IconButton(
                        tooltip: 'Move to cart',
                        icon: const Icon(Icons.shopping_cart_outlined),
                        onPressed: () {
                          CartRepo.instance.add(liveProduct);
                          // 💡 من الأفضل إزالته من قائمة الأمنيات بعد نقله للسلة
                          FavoritesRepo.instance.remove(liveProduct.id);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CartPage()),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      decoration: BoxDecoration(
        color: border.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: green)),
    );
  }

  Widget _buildDeletedCard() {
    return Container(
      height: 250, // تقريبي لحجم البطاقة
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sentiment_dissatisfied, color: hint),
              const SizedBox(height: 8),
              const Text('Product Not Found', style: TextStyle(color: textDark, fontWeight: FontWeight.bold)),
              Text('Removed from wishlist.', style: TextStyle(color: hint, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================================
// كلاس _BottomNav (لم يتم تعديله)
// ==========================================================

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex});
  final int currentIndex;

  static const kPrimary = WishlistPage.kPrimary;
  static const kBorder = WishlistPage.kBorder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 72,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: kBorder)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _item(
                  context,
                  icon: Icons.home_rounded,
                  label: 'Home',
                  selected: currentIndex == 0,
                  onTap: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const HomePage()),
                          (r) => false,
                    );
                  },
                ),
                _item(
                  context,
                  icon: Icons.favorite_border_rounded,
                  label: 'Wishlist',
                  selected: currentIndex == 1,
                  onTap: () {
                    // أنت بالفعل على wishlist — لا شيء
                  },
                ),
                const SizedBox(width: 56),
                _item(
                  context,
                  icon: Icons.inventory_2_outlined,
                  label: 'My Orders',
                  selected: currentIndex == 2,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MyOrdersPage()),
                    );
                  },
                ),
                _item(
                  context,
                  icon: Icons.settings_outlined,
                  label: 'Setting',
                  selected: currentIndex == 3,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ProfileSettingsPage()),
                    );
                  },
                ),
              ],
            ),
          ),
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
                  color: kPrimary.withOpacity(0.12),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: kPrimary.withOpacity(.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.shopping_cart_rounded,
                    color: kPrimary, size: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(BuildContext context,
      {required IconData icon,
        required String label,
        required bool selected,
        required VoidCallback onTap}) {
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