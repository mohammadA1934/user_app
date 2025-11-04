// lib/ui/payment_page.dart
import 'package:flutter/material.dart';
import 'home_page.dart';
import 'wishlist_page.dart';
import 'cart_page.dart';
import 'my_orders_page.dart';
import 'profile_settings_page.dart';

// ↓↓↓ لحفظ الطلب بعد الدفع ↓↓↓
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/cart_repo.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({
    super.key,
    required this.total, // إجمالي المبلغ القادم من صفحة Checkout
    this.orderSubtotal,
  });

  final double total;
  final double? orderSubtotal; // اختياري للعرض فقط

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  static const kPrimary = Color(0xFF34D399);
  static const kTextDark = Color(0xFF222222);
  static const kHint = Color(0xFF9AA0A6);
  static const kBorder = Color(0xFFE5E7EB);

  PaymentMethod _method = PaymentMethod.visa;

  // ===== حفظ الطلب في Firestore بعد نجاح الدفع =====
  Future<void> _placeOrder() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final itemsInCart = CartRepo.instance.items;
    if (itemsInCart.isEmpty) return;

    // تجهيز عناصر الطلب
    final orderItems = itemsInCart
        .map((it) => {
      'productId': it.product.id,
      'title': it.product.title,
      'price': double.parse(it.product.price.toStringAsFixed(2)),
      'qty': it.qty,
      'lineTotal': double.parse(
          (it.product.price * it.qty).toStringAsFixed(2)),
    })
        .toList();

    // محاولة استخراج storeId من أول منتج في السلة عبر Firestore
    String? storeId;
    try {
      final firstProductId = orderItems.first['productId'] as String;
      final snap = await FirebaseFirestore.instance
          .collection('products')
          .doc(firstProductId)
          .get();
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        final s = data['storeId'];
        if (s is String && s.isNotEmpty) {
          storeId = s;
        }
      }
    } catch (_) {
      // لو فشلنا، نكمل بدون storeId (لكن لن يظهر الطلب عند الأدمن بدونها)
    }

    final subtotal = (widget.orderSubtotal ?? widget.total);
    final tax = (widget.total - subtotal).clamp(0.0, double.infinity);

    // إنشاء الوثيقة
    await FirebaseFirestore.instance.collection('orders').add({
      'storeId': storeId, // ← مهم لظهور الطلب عند الأدمن
      'customerUid': user.uid,
      'customerName': user.displayName ?? 'Customer',
      'status': 'pending', // الحالة الأولية
      'items': orderItems,
      'subtotal': double.parse(subtotal.toStringAsFixed(2)),
      'tax': double.parse(tax.toStringAsFixed(2)),
      'total': double.parse(widget.total.toStringAsFixed(2)),
      'paymentMethod': _method.name,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // إفراغ السلة بعد إنشاء الطلب
    CartRepo.instance.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: _bottomBar(context),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kTextDark),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        elevation: 0.3,
        title: const Text(
          'Payment',
          style: TextStyle(color: kTextDark, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _rowKV('Order', _formatJD(widget.orderSubtotal ?? widget.total)),
              const Divider(height: 24),
              _rowKV('Total', _formatJD(widget.total)),
              const SizedBox(height: 14),
              const Text(
                'Payment',
                style: TextStyle(
                  color: kTextDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 10),

              // VISA
              _paymentTile(
                leading: Image.network(
                  'https://upload.wikimedia.org/wikipedia/commons/5/5e/Visa_Inc._logo.svg',
                  height: 18,
                  errorBuilder: (_, __, ___) => const Icon(Icons.credit_card),
                ),
                tail: const Text('********2109'),
                method: PaymentMethod.visa,
              ),

              const SizedBox(height: 10),

              // MasterCard
              _paymentTile(
                leading: Image.network(
                  'https://upload.wikimedia.org/wikipedia/commons/2/2a/Mastercard-logo.svg',
                  height: 18,
                  errorBuilder: (_, __, ___) => const Icon(Icons.credit_card),
                ),
                tail: const Text('********2109'),
                method: PaymentMethod.mastercard,
              ),

              const SizedBox(height: 10),

              // Apple Pay (كتمثيل)
              _paymentTile(
                leading: const Icon(Icons.apple, size: 20),
                tail: const Text('********2109'),
                method: PaymentMethod.applePay,
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // عنصر وسيلة دفع
  Widget _paymentTile({
    required Widget leading,
    required Widget tail,
    required PaymentMethod method,
  }) {
    final selected = _method == method;
    return InkWell(
      onTap: () => setState(() => _method = method),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? kPrimary : kBorder, width: 1.4),
          color: selected ? kPrimary.withOpacity(.06) : Colors.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(child: tail),
            Radio<PaymentMethod>(
              value: method,
              groupValue: _method,
              activeColor: kPrimary,
              onChanged: (v) => setState(() => _method = v!),
            ),
          ],
        ),
      ),
    );
  }

  // متابعة الدفع -> إظهار نافذة النجاح 3 ثوانٍ ثم الانتقال إلى MyOrdersPage
  Future<void> _onContinue() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                backgroundColor: Color(0x2234D399),
                radius: 34,
                child: Icon(Icons.check_circle, size: 56, color: kPrimary),
              ),
              SizedBox(height: 16),
              Text(
                'Payment done successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kTextDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    // حفظ الطلب ثم إغلاق الـ Dialog والانتقال للطلبات
    await _placeOrder();

    Navigator.of(context, rootNavigator: true).pop();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MyOrdersPage()),
          (r) => false,
    );
  }

  // صف نص يسار/يمين
  Widget _rowKV(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              k,
              style: const TextStyle(color: kHint, fontSize: 13.5),
            ),
          ),
          Text(
            v,
            style: const TextStyle(
              color: kTextDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _formatJD(double n) => '${n.toStringAsFixed(2)} JD';

  // Bottom bar بنفس تصميم الصورة (زر العربة دائري بالوسط)
  Widget _bottomBar(BuildContext context) {
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
              _navItem(
                icon: Icons.home_rounded,
                label: 'Home',
                selected: false,
                onTap: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomePage()),
                      (r) => false,
                ),
              ),
              _navItem(
                icon: Icons.favorite_border_rounded,
                label: 'Wishlist',
                selected: false,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WishlistPage()),
                ),
              ),
              const SizedBox(width: 56), // مكان للزر الدائري
              _navItem(
                icon: Icons.inventory_2_outlined,
                label: 'My Orders',
                selected: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyOrdersPage()),
                ),
              ),
              _navItem(
                icon: Icons.settings_outlined,
                label: 'Setting',
                selected: false,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ProfileSettingsPage()),
                ),
              ),
            ],
          ),

          // زر العربة الدائري في الوسط
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
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
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

enum PaymentMethod { visa, mastercard, applePay }
