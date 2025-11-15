import 'package:flutter/material.dart';
import '../data/favorites_repo.dart';
import '../models/product.dart';

import 'home_page.dart';
import 'product_detail_page.dart';
import 'cart_page.dart';
import 'my_orders_page.dart';
import 'profile_settings_page.dart';

// ✅ لإضافة المنتج إلى السلة عند الضغط على أيقونة العربة
import '../data/cart_repo.dart';
import 'rating_display.dart'; // ✅ تأكد من وجود هذا الاستيراد

// 🛑 تحويل الكلاس إلى StatefulWidget
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
  // 🛑 متغيرات للبحث
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // 🛑 دالة يتم استدعاؤها عند تغيير نص البحث
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
            // 🛑 تمرير الـ Controller وتفعيل الـ onChanged
            _searchBox(),
            const SizedBox(height: 8),
            // ✅ العنوان يعرض العدد الحقيقي (العدد قبل الفلترة)
            AnimatedBuilder(
              animation: FavoritesRepo.instance,
              builder: (_, __) {
                final count = FavoritesRepo.instance.items.length;
                return _titleRow(count);
              },
            ),
            const Divider(height: 16),
            Expanded(
              child: AnimatedBuilder(
                animation: FavoritesRepo.instance,
                builder: (_, __) {
                  final allItems = FavoritesRepo.instance.items; // List<Product>

                  // 🛑 تطبيق فلترة البحث
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
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: GridView.builder(
                      itemCount: filteredItems.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: .70,
                      ),
                      itemBuilder: (_, i) => _ProductCard(item: filteredItems[i]),
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

  // هيدر: سهم رجوع + عنوان + أفاتار يفتح Profile Settings
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
              );
            },
            child: CircleAvatar(
              radius: 18,
              backgroundColor: WishlistPage.kPrimary.withOpacity(0.15),
              child: const Icon(Icons.person, color: WishlistPage.kPrimary),
            ),
          ),
        ],
      ),
    );
  }

  // 🛑 استخدام الـ Controller المُضاف
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
              borderSide: const BorderSide(color: WishlistPage.kPrimary, width: 1.4),
            ),
          ),
          // تم تفعيل الـ listener في initState، فلا نحتاج لـ onChanged هنا.
        ),
      ),
    );
  }

  // ✅ تم حذف الـ _FilterChip
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
          // 🛑 تم حذف الـ _FilterChip هنا
        ],
      ),
    );
  }
}


// 🛑 تم حذف الكلاس _FilterChip بالكامل



class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.item});
  final Product item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: .5,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductDetailPage(product: item),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ صورة مرِنة لمنع ظهور شريط overflow الأصفر
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    item.image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: Colors.grey.shade200),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: WishlistPage.kTextDark,
                ),
              ),
              const SizedBox(height: 4),

              // 💡 إضافة عرض التقييم هنا
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${item.price.toStringAsFixed(2)} JD',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  // ✅ دمج الـ RatingDisplay هنا
                  RatingDisplay(
                    avgRating: item.avgRating,
                    ratingsCount: item.ratingsCount,
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
                  // ✅ حذف من الـ Wishlist
                  IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => FavoritesRepo.instance.remove(item.id),
                  ),
                  const SizedBox(width: 6),
                  // ✅ نقل إلى السلة ثم فتح صفحة السلة
                  IconButton(
                    tooltip: 'Move to cart',
                    icon: const Icon(Icons.shopping_cart_outlined),
                    onPressed: () {
                      CartRepo.instance.add(item);
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
  }
}

/// Bottom Nav بشكل الصورة (زر Cart دائري بالوسط)
class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex});
  final int currentIndex; // 0=Home, 1=Wishlist, 2=Orders, 3=Settings

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
                const SizedBox(width: 56), // مكان الزر الدائري
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

          // زر السلة الدائري بالمنتصف
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
                  color: kPrimary.withOpacity(0.12), // أخضر فاتح كما في الصورة
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