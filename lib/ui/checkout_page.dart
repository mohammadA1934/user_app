import 'package:flutter/material.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/cart_repo.dart';
import 'home_page.dart';
import 'payment_page.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  // ألوان موحّدة
  static const kPrimary = Color(0xFF34D399);
  static const kTextDark = Color(0xFF222222);
  static const kHint = Color(0xFF9AA0A6);
  static const kBorder = Color(0xFFE5E7EB);
  static const kError = Color(0xFFE7625F); // للخصم والرسائل

  // 🛑 المتغيرات الجديدة لجلب حالة الضريبة
  double _fetchedTaxRate = 0.0; // القيمة الافتراضية 0%
  late Future<void> _taxRateFuture;

  final _couponCtrl = TextEditingController();

  // 🛑 حالات الكوبون المطبقة
  double _discountValue = 0.0; // القيمة المخزنة (نسبة أو مبلغ)
  String _discountType = 'percentage'; // 'percentage' أو 'fixed'
  String _couponStatusMessage = ''; // رسالة حالة الكوبون

  // 🛑 جلب معرف المتجر من المنتجات في العربة
  String? get _storeId {
    return CartRepo.instance.items.firstOrNull?.product.storeId;
  }

  // 🛑 دالة جلب نسبة الضريبة من Firestore
  Future<void> _fetchTaxRate() async {
    final storeId = _storeId;
    if (storeId == null) {
      // لا يوجد منتجات، لا يوجد متجر، تبقى القيمة الافتراضية (0.0)
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(storeId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        // قيمة الضريبة محفوظة كـ (0.16)
        final rate = (data?['taxRate'] as num?);

        setState(() {
          // إذا كانت القيمة موجودة وصالحة، نستخدمها، وإلا تبقى 0.0
          _fetchedTaxRate = rate?.toDouble() ?? 0.0;
        });

        print('Tax Rate fetched successfully: ${_fetchedTaxRate * 100}%');
      } else {
        // وثيقة المتجر غير موجودة
        setState(() {
          _fetchedTaxRate = 0.0;
        });
      }
    } catch (e) {
      print('Error fetching tax rate: $e');
      setState(() {
        _fetchedTaxRate = 0.0;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // 🛑 بدء عملية جلب الضريبة
    _taxRateFuture = _fetchTaxRate();
    if (_couponValue() > 0) {
      _couponStatusMessage = 'Coupon applied.';
    }
  }

  @override
  void dispose() {
    _couponCtrl.dispose();
    super.dispose();
  }

  // 🛑 دالة حساب الخصم الفعلي بالدينار
  double _couponValue() {
    if (_discountValue == 0.0) return 0.0;
    final subtotal = CartRepo.instance.totalAmount; // الإجمالي قبل الخصم

    if (_discountType == 'percentage') {
      return subtotal * (_discountValue / 100);
    } else if (_discountType == 'fixed') {
      // لا يتجاوز الخصم المبلغ الإجمالي
      return min(_discountValue, subtotal);
    }
    return 0.0;
  }

  // 🛑 دالة لمسح حالة الكوبون
  void _clearCoupon() {
    setState(() {
      _clearCouponState();
    });
    _toast('Coupon cleared');
  }

  void _clearCouponState({String message = ''}) {
    _discountValue = 0.0;
    _discountType = 'percentage';
    _couponCtrl.clear();
    _couponStatusMessage = message;
  }


  // 🛑 دالة تطبيق الكوبون المُعدّلة (لضمان التحويل والتحديث)
  Future<void> _applyCoupon({String? codeOverride}) async {
    final code = (codeOverride ?? _couponCtrl.text).trim().toUpperCase();
    final subtotal = CartRepo.instance.totalAmount;

    if (subtotal <= 0) {
      _toast('Cannot apply coupon to an empty cart.');
      _clearCoupon();
      return;
    }
    if (code.isEmpty) {
      _clearCoupon();
      return;
    }
    final storeId = _storeId;
    if (storeId == null) {
      _toast('Store ID is missing. Cannot check coupon validity.');
      _clearCoupon();
      return;
    }

    // 1. البحث عن الكوبون
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('coupons')
          .where('storeId', isEqualTo: storeId)
          .where('code', isEqualTo: code)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _clearCouponState(message: 'Invalid or expired coupon code.');
        });
        return;
      }

      final couponData = querySnapshot.docs.first.data();

      // 💡 التحويل القوي لضمان قراءة القيمة من Firebase
      final rawDiscountValue = couponData['discount'];
      final discount = (rawDiscountValue is num)
          ? rawDiscountValue.toDouble()
          : double.tryParse(rawDiscountValue.toString()) ?? 0.0;

      final type = (couponData['type'] as String?) ?? 'percentage';

      final tsStart = couponData['startAt'] as Timestamp?;
      final tsEnd = couponData['endAt'] as Timestamp?;

      // 2. التحقق من الصلاحية الزمنية
      final now = DateTime.now();
      final start = tsStart?.toDate() ?? DateTime(1900);
      final end = tsEnd?.toDate() ?? DateTime(9999);

      if (!now.isBefore(start) && !now.isAfter(end)) {
        // الكوبون نشط
        setState(() {
          _discountValue = discount;
          _discountType = type;

          CartRepo.instance.notifyListeners(); // إجبار التحديث

          final discountAmount = _couponValue();

          print('Coupon value after applying: $discountAmount JD');

          _couponStatusMessage = 'Coupon applied successfully! Saved ${discountAmount.toStringAsFixed(2)} JD.';
        });
        _toast("Coupon applied: $code");
      } else {
        // الكوبون منتهي أو لم يبدأ بعد
        setState(() {
          _clearCouponState(message: 'Coupon is not active yet or has expired.');
        });
      }

    } catch (e) {
      setState(() {
        _clearCouponState(message: 'An error occurred. Try again.');
      });
      print('Error applying coupon: $e');
      _toast('Error applying coupon. Check console for details.');
    }
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // 🛑 دالة عند النقر على كوبون متاح (Coupon Chip)
  void _selectAvailableCoupon(String code) {
    _couponCtrl.text = code;
    _applyCoupon(codeOverride: code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kTextDark),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.3,
        title: const Text(
          'Checkout',
          style: TextStyle(color: kTextDark, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        // 🛑 تغليف الـ Body بالـ FutureBuilder لجلب قيمة الضريبة أولاً
        child: FutureBuilder(
          future: _taxRateFuture,
          builder: (context, snapshot) {
            // عرض دائرة التحميل أثناء جلب الضريبة
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // بمجرد الانتهاء من جلب الضريبة، نعرض المحتوى
            return AnimatedBuilder(
              animation: CartRepo.instance,
              builder: (_, __) {
                final items = CartRepo.instance.items;
                final storeId = _storeId; // جلب الـ Store ID

                final rawSubtotal = CartRepo.instance.totalAmount;
                // 🛑 قيمة الخصم الفعلي
                final discountAmount = _couponValue();

                // 🛑 حساب الإجمالي بعد الخصم
                final orderSubtotalAfterDiscount =
                (rawSubtotal - discountAmount).clamp(0.0, double.infinity);

                // 🛑 استخدام قيمة الضريبة المجلوبة (_fetchedTaxRate)
                final taxRate = _fetchedTaxRate; // مثل 0.16 أو 0.0

                final tax =
                double.parse((orderSubtotalAfterDiscount * taxRate).toStringAsFixed(2));
                final total = (orderSubtotalAfterDiscount + tax).clamp(0.0, double.infinity);

                return Column(
                  children: [
                    // المنتجات (الكود كما هو)
                    Flexible(
                      fit: FlexFit.loose,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        itemCount: items.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final it = items[i];
                          final p = it.product;
                          return Container(
                            // كود عرض المنتجات الأصلي
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: kBorder),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    p.image,
                                    width: 90,
                                    height: 90,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 90,
                                      height: 90,
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: kTextDark,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),

                                      Row(
                                        children: [
                                          _qtyButton(
                                            icon: Icons.remove_rounded,
                                            onTap: () =>
                                                CartRepo.instance.decrement(p.id),
                                          ),
                                          Container(
                                            width: 42,
                                            alignment: Alignment.center,
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 6),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 6),
                                            decoration: BoxDecoration(
                                              border:
                                              Border.all(color: kBorder),
                                              borderRadius:
                                              BorderRadius.circular(8),
                                            ),
                                            child: Text('${it.qty}',
                                                style: const TextStyle(
                                                    fontWeight:
                                                    FontWeight.w700)),
                                          ),
                                          _qtyButton(
                                            icon: Icons.add_rounded,
                                            onTap: () =>
                                                CartRepo.instance.increment(p.id),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${p.price.toStringAsFixed(2)} JD',
                                      style: const TextStyle(
                                        color: kTextDark,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    IconButton(
                                      tooltip: 'Remove',
                                      onPressed: () =>
                                          CartRepo.instance.remove(p.id),
                                      icon: const Icon(
                                          Icons.delete_outline_rounded),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Apply Coupon (الكود كما هو)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                      child: Row(
                        children: [
                          const Text('Apply Coupon:',
                              style: TextStyle(
                                  color: kTextDark,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _couponCtrl,
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'e.g. SAVE10',
                                hintStyle: const TextStyle(color: kHint),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: kBorder),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: kBorder),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: kPrimary, width: 1.4),
                                ),
                                // 🛑 زر مسح الكوبون
                                suffixIcon: _discountValue > 0
                                    ? IconButton(
                                  icon: const Icon(Icons.close, size: 20),
                                  onPressed: _clearCoupon,
                                )
                                    : null,
                              ),
                              onSubmitted: (_) => _applyCoupon(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _applyCoupon,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'apply',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 🛑 الكوبونات المتاحة للنقر (الكود كما هو)
                    if (storeId != null)
                      _AvailableCouponsWidget(
                        storeId: storeId,
                        onCouponSelected: _selectAvailableCoupon,
                        kPrimary: kPrimary,
                      ),
                    const SizedBox(height: 8),

                    // رسالة حالة الكوبون (الكود كما هو)
                    if (_couponStatusMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _couponStatusMessage,
                            style: TextStyle(
                              color: _discountValue > 0 ? kPrimary : kError,
                              fontStyle: FontStyle.italic,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),

                    // ======= الجزء السفلي ( Order Payment Details) =======
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          const Divider(),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Order Payment Details',
                              style: TextStyle(
                                color: kTextDark,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // 🛑 إجمالي المبلغ قبل الخصم
                          _priceRow('Subtotal:',
                              '${rawSubtotal.toStringAsFixed(2)} JD'),

                          // 🛑 عرض صف الخصم إذا كان مطبقاً
                          if (discountAmount > 0)
                            _priceRow('Coupon Discount:',
                                '- ${discountAmount.toStringAsFixed(2)} JD',
                                valueColor: kError),

                          // 🛑 عرض الضريبة مع النسبة المئوية
                          _priceRow(
                              'Tax (${(taxRate * 100).toStringAsFixed(0)}%):',
                              '${tax.toStringAsFixed(2)} JD'),

                          const SizedBox(height: 8),
                          const Divider(),
                          const SizedBox(height: 6),
                          // 🛑 عرض الإجمالي
                          Row(
                            children: [
                              const Text('Order Total',
                                  style: TextStyle(
                                      color: kTextDark,
                                      fontWeight: FontWeight.w700)),
                              const Spacer(),
                              Text(
                                '${total.toStringAsFixed(2)} JD',
                                style: const TextStyle(
                                  color: kTextDark,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),

                    // الأزرار: Proceed / Cancel (الكود كما هو)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                if (CartRepo.instance.items.isEmpty) {
                                  _toast('Your cart is empty');
                                  return;
                                }
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PaymentPage(
                                      total: total,
                                      orderSubtotal: orderSubtotalAfterDiscount,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimary,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Proceed to Payment',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                CartRepo.instance.clear();
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                      builder: (_) => const HomePage()),
                                      (r) => false,
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: const Color(0xFFE7625F),
                                side: BorderSide.none,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _qtyButton({required IconData icon, required VoidCallback onTap}) {
    return Ink(
      decoration: BoxDecoration(
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: kTextDark),
        ),
      ),
    );
  }

  Widget _priceRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: kHint)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? kTextDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// 🛑 الـ Widget الجديد لعرض الكوبونات المتاحة للنقر (تم التعديل عليه)
class _AvailableCouponsWidget extends StatelessWidget {
  const _AvailableCouponsWidget({
    required this.storeId,
    required this.onCouponSelected,
    required this.kPrimary,
  });

  final String storeId;
  final Function(String code) onCouponSelected;
  final Color kPrimary;

  @override
  Widget build(BuildContext context) {
    // جلب جميع كوبونات المتجر
    final couponsStream = FirebaseFirestore.instance
        .collection('coupons')
        .where('storeId', isEqualTo: storeId)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: couponsStream,
      builder: (context, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 1,
            child: LinearProgressIndicator(),
          );
        }

        final docs = s.data?.docs ?? [];

        // فلترة الكوبونات النشطة
        final activeCoupons = docs.where((d) {
          final m = d.data() as Map<String, dynamic>;
          final tsStart = m['startAt'] as Timestamp?;
          final tsEnd = m['endAt'] as Timestamp?;

          final now = DateTime.now();
          final start = tsStart?.toDate() ?? DateTime(1900);
          final end = tsEnd?.toDate() ?? DateTime(9999);

          // الشرط: لم يبدأ بعد AND لم ينتهِ بعد
          return !now.isBefore(start) && !now.isAfter(end);
        }).toList();

        if (activeCoupons.isEmpty) {
          return const SizedBox.shrink();
        }

        // عرض الكوبونات النشطة
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Available Coupons:',
                style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF9AA0A6), fontSize: 13),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 38, // ارتفاع ثابت للكوبونات
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: activeCoupons.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final data = activeCoupons[index].data() as Map<String, dynamic>;
                    final code = data['code'] as String? ?? 'N/A';

                    // 💡 التعديل الحاسم هنا لضمان قراءة القيمة من Firebase
                    final rawDiscountValue = data['discount'];
                    final discount = (rawDiscountValue is num)
                        ? rawDiscountValue.toDouble()
                        : double.tryParse(rawDiscountValue.toString()) ?? 0.0;

                    final type = (data['type'] as String?) ?? 'percentage';

                    String displayValue = type == 'percentage'
                        ? '${discount.toStringAsFixed(0)}%' // لعرض 20%
                        : '${discount.toStringAsFixed(2)} JD';

                    return GestureDetector(
                      onTap: () => onCouponSelected(code),
                      child: Chip(
                        label: Text(
                          '$code ($displayValue)',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 12),
                        ),
                        backgroundColor: kPrimary.withOpacity(0.9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}