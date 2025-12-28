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
import 'rating_display.dart'; // ✅ تأكد من وجود هذا الاستيراد

// 🛑 كلاس مساعد لحالة المتجر
class StoreStatusResult {
  final bool isOpen;
  final String message; // مثال: (Open now (9:00 - 17:00) / Closed now. Opens at 9:00)

  StoreStatusResult(this.isOpen, this.message);
}

// 💡 التعديل 1: تحويل StorePage إلى StatefulWidget
class StorePage extends StatefulWidget {
  const StorePage({
    super.key,
    required this.storeId, // ← معرف المتجر (هو نفسه id وثيقة shops)
    required this.storeName,
    this.storeLogo,
  });

  final String storeId;
  final String storeName;
  final String? storeLogo;

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  // 💡 الألوان (لتكون متاحة داخل الـ State)
  static const green = Color(0xFF34D399);
  static const textDark = Color(0xFF222222);
  static const hint = Color(0xFF9AA0A6);
  static const border = Color(0xFFE5E7EB);
  static const red = Color(0xFFEF4444);

  // 💡 التعديل 2: متغيرات الحالة للبحث وحالة المتجر
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  // 🛑 متغير لتخزين حالة المتجر الديناميكية
  StoreStatusResult _storeStatus = StoreStatusResult(true, 'Loading...');

  // ✅ متغيرات جديدة لبيانات المستخدم
  User? _user;
  String? _userPhotoUrl;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 💡 التعديل 3: التخلص من المتحكم
  @override
  void initState() {
    super.initState();
    _loadUserProfile(); // ✅ تحميل بيانات المستخدم عند البداية
  }

  // ✅ دالة جلب بيانات المستخدم والصورة
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
    _searchController.dispose();
    super.dispose();
  }

  // 🛑 دالة منطق حساب حالة المتجر (مصححة لتطابق تسلسل Mon, Tue, Wen...)
  StoreStatusResult _getStoreStatus(Map<String, dynamic>? workingHours) {
    if (workingHours == null || workingHours.isEmpty) {
      // إذا لم يتم تحديد الأوقات، نعتبره مفتوحاً مؤقتاً لتجنب إغلاق المتاجر غير المهيئة
      return StoreStatusResult(true, 'Open (Hours not fully configured)');
    }

    final now = DateTime.now();

    // 💡 التصحيح: يجب أن يبدأ التسلسل بـ 'Mon' (حيث now.weekday=1)
    final dayKeys = ['Mon', 'Tue', 'Wen', 'Thu', 'Fri', 'Sat', 'Sun'];
    // now.weekday يعطي 1 للإثنين و 7 للأحد
    final currentDayKey = dayKeys[now.weekday - 1];

    final todayHours = workingHours[currentDayKey] as Map<String, dynamic>?;

    if (todayHours == null || todayHours['status'] == 'closed') {
      return StoreStatusResult(false, 'Closed today.');
    }

    try {
      final startTimeStr = todayHours['start'] as String; // e.g., "09:00"
      final endTimeStr = todayHours['end'] as String;      // e.g., "17:00"

      final nowTimeMinutes = now.hour * 60 + now.minute;

      final startParts = startTimeStr.split(':').map(int.parse).toList();
      final startTimeMinutes = startParts[0] * 60 + startParts[1];

      final endParts = endTimeStr.split(':').map(int.parse).toList();
      final endTimeMinutes = endParts[0] * 60 + endParts[1];

      // التحقق من الحالة
      if (nowTimeMinutes >= startTimeMinutes && nowTimeMinutes < endTimeMinutes) {
        return StoreStatusResult(true, 'Open now ($startTimeStr - $endTimeStr)');
      } else if (nowTimeMinutes < startTimeMinutes) {
        return StoreStatusResult(false, 'Closed now. Opens at $startTimeStr.');
      } else {
        return StoreStatusResult(false, 'Closed. Reopens tomorrow.');
      }

    } catch (e) {
      // إذا كان هناك خطأ في تنسيق البيانات
      return StoreStatusResult(true, 'Open (Hours data error)');
    }
  }


  // 💡 التعديل 4: شريط البحث المُحسَّن
  Widget _buildSearch() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: border.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search products in ${widget.storeName}...',
          prefixIcon: const Icon(Icons.search_rounded, color: hint),
          hintStyle: const TextStyle(color: hint, fontSize: 14),
          filled: false,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase().trim();
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🛑 StreamBuilder لجلب بيانات المتجر (بما فيها أوقات العمل)
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('shops').doc(widget.storeId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // يمكن عرض تخطيط أساسي بينما يتم التحميل
          return _buildScaffold(context, StoreStatusResult(true, 'Loading store data...'), isDataLoading: true);
        }

        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final workingHours = data?['workingHours'] as Map<String, dynamic>?;

        // 🛑 تحديث حالة المتجر
        _storeStatus = _getStoreStatus(workingHours);

        // بناء الواجهة بعد جلب البيانات
        return _buildScaffold(context, _storeStatus);
      },
    );
  }

  // 🛑 دالة بناء Scaffold منفصلة لاستخدامها داخل الـ StreamBuilder
  Widget _buildScaffold(BuildContext context, StoreStatusResult status, {bool isDataLoading = false}) {
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
              ).then((_) {
                // ✅ إعادة تحميل الصورة عند العودة من صفحة الإعدادات
                _loadUserProfile();
              });
            },
            child: CircleAvatar(
              radius: 16,
              backgroundColor: border,
              // ✅ استخدام صورة المستخدم
              backgroundImage: (_userPhotoUrl != null && _userPhotoUrl!.isNotEmpty)
                  ? NetworkImage(_userPhotoUrl!) as ImageProvider<Object>
                  : null,
              child: (_userPhotoUrl == null || _userPhotoUrl!.isEmpty)
                  ? const Icon(Icons.person, color: textDark, size: 18)
                  : null,
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
              _buildSearch(),
              const SizedBox(height: 12),

              // سطر اسم المتجر + أيقونات + حالة المتجر
              Row(
                children: [
                  if (widget.storeLogo != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: CircleAvatar(
                        backgroundColor: border,
                        backgroundImage: NetworkImage(widget.storeLogo!),
                        radius: 14,
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Icon(Icons.local_cafe, color: textDark),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.storeName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // 🛑 عرض حالة المتجر
                        Text(
                          'Status: ${status.message}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: status.isOpen ? green : red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // أيقونة الرسالة → محادثة حقيقية
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _ChatScreen(
                            storeId: widget.storeId,
                            storeName: widget.storeName,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline, color: textDark),
                  ),

                ],
              ),
              const SizedBox(height: 8),

              // شبكة المنتجات (حقيقية من Firestore)
              Expanded(
                child: isDataLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _StoreProductsGrid(
                  storeId: widget.storeId,
                  searchQuery: _searchQuery,
                  isShopOpen: status.isOpen, // 🛑 تمرير حالة الفتح
                ),
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
  const _StoreProductsGrid({
    required this.storeId,
    required this.searchQuery,
    required this.isShopOpen, // 🛑 استقبال حالة الفتح
  });

  final String storeId;
  final String searchQuery;
  final bool isShopOpen; // 🛑 حالة المتجر

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

        // 💡 التعديل 6: تطبيق الفلترة المحلية بناءً على نص البحث
        final List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredDocs;

        if (searchQuery.isEmpty) {
          filteredDocs = docs;
        } else {
          filteredDocs = docs.where((d) {
            final data = d.data();
            final name = (data['name'] ?? '').toString().toLowerCase();
            final desc = (data['description'] ?? data['desc'] ?? '').toString().toLowerCase();

            // تحقق من تطابق الاسم أو الوصف مع نص البحث
            return name.contains(searchQuery) || desc.contains(searchQuery);
          }).toList();
        }

        if (filteredDocs.isEmpty) {
          final message = searchQuery.isEmpty
              ? 'No products to show'
              : 'No results found for "$searchQuery"';
          return Center(child: Text(message));
        }

        // 🛑 استخدام القائمة المفلترة
        return GridView.builder(
          padding: EdgeInsets.zero,
          itemCount: filteredDocs.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            // ارتفاع البطاقة مناسب لتفادي الـ overflow
            childAspectRatio: .66,
          ),
          itemBuilder: (context, index) {
            final d = filteredDocs[index].data();

            // 1️⃣ جلب القيم الأساسية من البيانات
            double currentPrice = (d['price'] is num) ? (d['price'] as num).toDouble() : 0.0;
            double? oldPriceData = (d['oldPrice'] is num) ? (d['oldPrice'] as num).toDouble() : null;
            bool hasDiscount = d['hasDiscount'] ?? false;
            Timestamp? expiry = d['discountExpiry'] as Timestamp?;

            // 2️⃣ 🛑 منطق إرجاع السعر للأصل تلقائياً عند انتهاء الوقت
            if (hasDiscount && expiry != null) {
              if (DateTime.now().isAfter(expiry.toDate())) {
                // إذا انتهى الوقت، السعر الحالي يصبح هو السعر القديم
                if (oldPriceData != null) {
                  currentPrice = oldPriceData;
                }
                hasDiscount = false;
                oldPriceData = null; // نلغي السعر المشطوب في الواجهة

                // تحديث قاعدة البيانات فوراً (Firestore) لإلغاء الخصم نهائياً
                FirebaseFirestore.instance
                    .collection('products')
                    .doc(filteredDocs[index].id)
                    .update({
                  'price': currentPrice,
                  'hasDiscount': false,
                  'oldPrice': null,
                  'discountExpiry': null,
                }).catchError((e) => debugPrint("Auto-update failed: $e"));
              }
            }

            // 3️⃣ تحويل وثيقة Firestore -> Product موديل التطبيق (بالسعر المصحح)
            final product = Product(
              id: filteredDocs[index].id,
              title: (d['name'] ?? 'Product').toString(),
              desc: (d['description'] ?? d['desc'] ?? '').toString(),
              price: currentPrice, // ✅ هنا السعر المعدل
              image: (d['imageUrl'] ?? d['image'] ?? '').toString(),
              storeId: (d['storeId'] ?? '').toString(),
              avgRating: (d['avgRating'] as num? ?? 0.0).toDouble(),
              ratingsCount: (d['ratingsCount'] as num? ?? 0).toInt(),
            );

            // 4️⃣ عرض البطاقة
            return _ProductCardUI(
              product: product,
              oldPrice: oldPriceData, // سيكون null إذا انتهى الخصم
              isShopOpen: isShopOpen,
              onOpenDetails: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailPage(product: product),
                  ),
                );
              },
              onCart: () {
                if (!isShopOpen) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cannot add to cart. The shop is currently closed.'),
                      backgroundColor: _StorePageState.red,
                    ),
                  );
                  return;
                }

                CartRepo.instance.add(product);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartPage()),
                );
              },
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
    this.oldPrice, // 👈 استقبال السعر القديم
    required this.onOpenDetails,
    required this.onCart,
    required this.onWishlist,
    required this.isShopOpen, // 🛑 استقبال حالة المتجر
  });

  final Product product;
  final double? oldPrice; // 👈 إضافة المتغير هنا
  final VoidCallback onOpenDetails;
  final VoidCallback onCart;
  final VoidCallback onWishlist;
  final bool isShopOpen; // 🛑 حالة المتجر

  static const textDark = Color(0xFF222222);
  static const hint = Color(0xFF9AA0A6);
  static const border = Color(0xFFE5E7EB);
  static const green = Color(0xFF34D399);

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

                  // 💡 إضافة RatingDisplay هنا
                  RatingDisplay(
                    avgRating: product.avgRating,
                    ratingsCount: product.ratingsCount,
                    starSize: 14,
                    textSize: 12.5,
                    // لا نعرض عدد المراجعات في البطاقة لضيق المساحة

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

                  // 👈 تعديل: عرض السعر الجديد وبجانبه القديم مشطوباً


                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // السعر الجديد (الحالي)
                      Text(
                        '${product.price.toStringAsFixed(2)} JD',
                        style: const TextStyle(
                          color: textDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),

                      if (oldPrice != null && oldPrice! > product.price) ...[
                        const SizedBox(width: 8),
                        // ✨ السعر القديم مع JD وتنسيق الماركر الأصفر
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.yellow.withOpacity(0.35), // خلفية صفراء للفت الانتباه
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${oldPrice!.toStringAsFixed(2)} JD', // 🟢 أضفنا JD هنا
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.9),
                              fontSize: 11,
                              fontWeight: FontWeight.w900, // خط عريض جداً
                              decoration: TextDecoration.lineThrough, // خط الشطب
                              decorationColor: Colors.red.shade700,   // شطب أحمر غامق
                              decorationThickness: 3.5,              // خط شطب سميك جداً
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),

                  // سطر الأيقونات
                  Row(
                    children: [
                      const Spacer(),
                      // القلب → Wishlist
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
                        // 🛑 تغيير اللون إذا كان المتجر مغلقاً
                        icon: Icon(
                            Icons.shopping_cart_outlined,
                            size: 18,
                            color: isShopOpen ? green : Colors.grey.shade400
                        ),
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

  @override
  void dispose() {
    _txt.dispose();
    super.dispose();
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
                // final uid = FirebaseAuth.instance.currentUser?.uid; // غير مستخدم
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