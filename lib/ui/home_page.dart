import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'store_page.dart';

// الصفحات المطلوبة للتنقل من الـ Bottom Bar
import 'wishlist_page.dart';
import 'cart_page.dart';
import 'my_orders_page.dart';
import 'profile_settings_page.dart';
import 'product_detail_page.dart'; // قد تحتاج لهذا لاحقًا للانتقال لصفحة المنتج

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ألوان موحّدة
  static const kPrimary = Color(0xFF34D399);
  static const kTextDark = Color(0xFF222222);
  static const kHint = Color(0xFF9AA0A6);
  static const kBorder = Color(0xFFE5E7EB);

  // اختيار التصنيف الحالي
  int _selectedCat = 0;

  // 💡 حقل حالة البحث والمتحكم (Controller)
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // 🔗 مراجع Firestore
  CollectionReference<Map<String, dynamic>> get _catsCol =>
      FirebaseFirestore.instance.collection('categories');
  CollectionReference<Map<String, dynamic>> get _shopsCol =>
      FirebaseFirestore.instance.collection('shops');
  // 💡 التعديل 1: مرجع المنتجات (سيتم إبقاؤه لكنه لن يستخدم في البحث)
  CollectionReference<Map<String, dynamic>> get _productsCol =>
      FirebaseFirestore.instance.collection('products');

  // 💡 التعديل 2: التخلص من المتحكم عند إغلاق الصفحة
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------
  // 🛑 دالة منطق حساب حالة المتجر (مُصححة لتطابق تنسيق DB)
  // -----------------------------------------------------------
  String _getStoreStatus(Map<String, dynamic>? workingHours) {
    if (workingHours == null || workingHours.isEmpty) {
      return 'Status unknown'; // إذا لم يتم تحديد الأوقات
    }

    final now = DateTime.now();
    // الحصول على اليوم الحالي كنص (Mon, Tue, Wed, Thu, Fri, Sat, Sun)
    // now.weekday يعطي 1 للإثنين و 7 للأحد
    final dayKeys = ['Mon', 'Tue', 'Wen', 'Thu', 'Fri', 'Sat', 'Sun'];
    final currentDayKey = dayKeys[now.weekday - 1]; // تم تصحيح هذا المنطق

    final todayHours = workingHours[currentDayKey] as Map<String, dynamic>?;

    if (todayHours == null || todayHours['status'] == 'closed') {
      return 'Closed today';
    }

    try {
      final startTimeStr = todayHours['start'] as String; // e.g., "09:00"
      final endTimeStr = todayHours['end'] as String;     // e.g., "17:00"

      // تحويل الوقت الحالي إلى دقائق من منتصف الليل
      final nowTimeMinutes = now.hour * 60 + now.minute;

      // تحليل وقت البدء والانتهاء إلى دقائق
      final startParts = startTimeStr.split(':').map(int.parse).toList();
      final startTimeMinutes = startParts[0] * 60 + startParts[1];

      final endParts = endTimeStr.split(':').map(int.parse).toList();
      final endTimeMinutes = endParts[0] * 60 + endParts[1];

      // 🛑 التحقق من الحالة
      if (nowTimeMinutes >= startTimeMinutes && nowTimeMinutes < endTimeMinutes) {
        // مفتوح حالياً
        return 'Open now ($startTimeStr - $endTimeStr)';
      } else if (nowTimeMinutes < startTimeMinutes) {
        // مغلق حالياً، سيفتح لاحقاً اليوم
        return 'Closed now. Opens at $startTimeStr';
      } else {
        // مغلق حالياً، وقت العمل انتهى لهذا اليوم
        return 'Closed. Reopens tomorrow';
      }

    } catch (e) {
      // إذا كان هناك خطأ في تنسيق البيانات (مثلاً: "start" ليس String)
      return 'Hours data error';
    }
  }

  // -----------------------------------------------------------
  // 💡 التعديل 4: دالة جلب نتائج البحث (المتاجر فقط)
  // -----------------------------------------------------------
  Future<List<Map<String, dynamic>>> _fetchSearchResults() async {
    // 1. جلب جميع المتاجر النشطة (مع أوقات العمل)
    final allShopsSnapshot = await _shopsCol.where('status', isEqualTo: 'active').get();

    // 2. تطبيق فلترة البحث على المتاجر وتضمين أوقات العمل
    final shopResults = allShopsSnapshot.docs.where((d) {
      final data = d.data();
      final name = (data['name'] ?? '').toString().toLowerCase();
      final desc = (data['about'] ?? data['description'] ?? '').toString().toLowerCase();

      // إذا كان البحث فارغاً، نعرض جميع المتاجر النشطة
      if (_searchQuery.isEmpty) return true;

      return name.contains(_searchQuery) || desc.contains(_searchQuery);
    }).map((d) {
      final data = d.data();
      data['id'] = d.id;
      data['type'] = 'shop'; // تحديد نوع النتيجة

      // 🛑 جلب أوقات العمل وتضمينها
      data['workingHours'] = data['workingHours'] as Map<String, dynamic>?;

      return data;
    }).toList();

    // 3. فلترة المتاجر حسب التصنيف (تطبق على المتاجر فقط)
    List<Map<String, dynamic>> shopsByCat;
    if (_searchQuery.isEmpty && _selectedCat != 0) {
      final selectedName = _selectedCategoryNameFromStream();
      shopsByCat = shopResults.where((item) {
        final shopCat = (item['category'] ?? '').toString();
        return shopCat.toLowerCase() == selectedName.toLowerCase();
      }).toList();
    } else {
      shopsByCat = shopResults;
    }

    // 4. النتيجة النهائية هي قائمة المتاجر المفلترة فقط
    return shopsByCat;
  }

  // -----------------------------------------------------------
  // البناء والعرض
  // -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: _buildBottomNav(context),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            const SizedBox(height: 8),
            _buildSearch(),
            const SizedBox(height: 8),
            _buildCategories(),
            const Divider(height: 16),
            Expanded(child: _buildStoresList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back to login',
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
          ),
          const Spacer(),
          const Text(
            'Shoppinest',
            style: TextStyle(
              color: kPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
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
              backgroundColor: kPrimary.withOpacity(.15),
              child: const Icon(Icons.person, color: kPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 44,
        child: TextField(
          controller: _searchController, // ربط المتحكم
          decoration: InputDecoration(
            // 💡 التعديل: تغيير نص التلميح (Hint Text) ليعكس البحث عن المتاجر فقط
            hintText: 'Search any Store...',
            prefixIcon: const Icon(Icons.search_rounded, color: kHint),
            hintStyle: const TextStyle(color: kHint),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kPrimary, width: 1.4),
            ),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase().trim();
            });
          },
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _catsCol.orderBy('name').snapshots(),
      builder: (context, snap) {
        // نبني قائمة الفئات: All + باقي الفئات الموجودة
        final List<String> cats = ['All'];
        if (snap.hasData) {
          for (final d in snap.data!.docs) {
            final n = (d.data()['name'] ?? '').toString().trim();
            if (n.isNotEmpty) cats.add(n);
          }
        }

        // ✅ حدّث النسخة المخزنة محليًا لتفادي RangeError
        _updateLastCats(cats);

        // تأكد أن selected index ضمن الحدود بعد أي تحديث للفئات
        if (_selectedCat >= cats.length) {
          _selectedCat = 0;
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(cats.length, (i) {
                      final selected = _selectedCat == i;
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ChoiceChip(
                          label: Text(cats[i]),
                          selected: selected,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : kTextDark,
                            fontWeight: FontWeight.w600,
                          ),
                          side: const BorderSide(color: kBorder),
                          selectedColor: kPrimary,
                          backgroundColor: Colors.white,
                          onSelected: (_) => setState(() => _selectedCat = i),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 💡 التعديل 5: استخدام FutureBuilder بدلاً من StreamBuilder لعرض النتائج
  Widget _buildStoresList() {
    // 🛑 يتم إعادة تشغيل FutureBuilder في كل مرة تتغير فيها _searchQuery أو _selectedCat
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchSearchResults(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Error: ${snap.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final finalFilteredList = snap.data ?? [];

        if (finalFilteredList.isEmpty) {
          final message = (_searchQuery.isEmpty && _selectedCat == 0)
              ? 'No shops to show'
              : 'No results found for "$_searchQuery" or selected category.';
          return Center(child: Text(message));
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          itemCount: finalFilteredList.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = finalFilteredList[index];

            // منطق عرض المتجر
            final name   = (item['name'] ?? 'Shop').toString();
            final desc   = (item['about'] ?? item['description'] ?? '').toString();
            final logoUrl= (item['logoUrl'] ?? '').toString();

            // 🛑 جلب وحساب حالة المتجر
            final workingHours = item['workingHours'] as Map<String, dynamic>?;
            final statusText = _getStoreStatus(workingHours);

            // تحديد اللون بناءً على حالة الفتح (مقارنة بالكلمة الأولى في النص)
            final bool isOpen = statusText.startsWith('Open');
            final Color statusColor = isOpen ? kPrimary : Colors.red.shade400;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              leading: _ShopAvatar(logoUrl: logoUrl),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, color: kTextDark)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, height: 1.2)),
                  const SizedBox(height: 6),
                  // 🛑 عرض حالة المتجر الديناميكية
                  Row(
                    children: [
                      const SizedBox(width: 10),
                      Text(
                          '• $statusText',
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.w600)
                      ),
                    ],
                  ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black45),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => StorePage(
                  storeId: item['id'],
                  storeName: name,
                  storeLogo: logoUrl,
                )));
              },
            );
          },
        );
      },
    );
  }

  // اسم التصنيف المختار حاليًا (من واجهة الـ Chips)
  String _selectedCategoryNameFromStream() {
    // حماية من الخروج عن الحدود إذا _lastCats لم يتحدث بعد
    if (_selectedCat <= 0) return '';
    if (_selectedCat >= _lastCats.length) return '';
    return _lastCats[_selectedCat];
  }

  // نخزن آخر قائمة تم بناؤها للفئات (مع All بالindex 0)
  List<String> _lastCats = const ['All'];

  // نحدّث _lastCats داخل الـ StreamBuilder للفئات
  void _updateLastCats(List<String> cats) {
    _lastCats = cats.isEmpty ? const ['All'] : List<String>.from(cats);
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // عناصر البار
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _BarItem(
                icon: Icons.home_rounded,
                label: 'Home',
                selected: true,
                onTap: () {}, // أنت على الهوم
              ),
              _BarItem(
                icon: Icons.favorite_border_rounded,
                label: 'Wishlist',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WishlistPage()),
                  );
                },
              ),
              const SizedBox(width: 56), // مكان الزر الدائري
              _BarItem(
                icon: Icons.inventory_2_outlined,
                label: 'My Orders',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyOrdersPage()),
                  );
                },
              ),
              _BarItem(
                icon: Icons.settings_outlined,
                label: 'Setting',
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

          // زر الكارت الدائري بالمنتصف (خلفية خضراء فاتحة + أيقونة خضراء)
          Positioned(
            bottom: 8,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartPage()),
                );
              },
              borderRadius: BorderRadius.circular(32),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.12), // الأخضر الفاتح
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: kPrimary.withOpacity(.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
}

// عنصر لعنصر الـ BottomBar (نص + أيقونة)
class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? _HomePageState.kPrimary : Colors.black54;
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

// صورة المتجر (شبكة أو رمز افتراضي)
class _ShopAvatar extends StatelessWidget {
  const _ShopAvatar({required this.logoUrl});
  final String logoUrl;

  @override
  Widget build(BuildContext context) {
    if (logoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Image.network(
          logoUrl,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: _HomePageState.kPrimary.withOpacity(.12),
      borderRadius: BorderRadius.circular(22),
    ),
    child: const Icon(Icons.store, color: Color(0xFF7C8A98)),
  );
}

// 💡 التعديل 6: تم إبقاء هذا الكلاس ولكنه لن يُستخدم في دالة _buildStoresList
class _ProductSearchAvatar extends StatelessWidget {
  const _ProductSearchAvatar({required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: _HomePageState.kBorder,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(Icons.shopping_bag_outlined, color: _HomePageState.kHint),
  );
}