import 'package:flutter/material.dart';
import '../data/cart_repo.dart';
import 'home_page.dart';
import 'payment_page.dart'; // للانتقال لصفحة الدفع

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

  // إعدادات الضرائب/الخصم
  static const double _taxRate = 0.067; // ~6.7%
  final _couponCtrl = TextEditingController();
  double _discount = 0.0;

  @override
  void dispose() {
    _couponCtrl.dispose();
    super.dispose();
  }

  void _applyCoupon() {
    final code = _couponCtrl.text.trim().toUpperCase();
    final subtotal = CartRepo.instance.totalAmount;
    if (code == 'SAVE10' && subtotal > 0) {
      setState(() => _discount = subtotal * 0.10);
      _toast('Coupon applied: 10% off');
    } else if (code.isEmpty) {
      setState(() => _discount = 0);
      _toast('Coupon cleared');
    } else {
      setState(() => _discount = 0);
      _toast('Invalid coupon');
    }
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

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
        child: AnimatedBuilder(
          animation: CartRepo.instance,
          builder: (_, __) {
            final items = CartRepo.instance.items;

            final rawSubtotal = CartRepo.instance.totalAmount;
            final orderSubtotal =
            (rawSubtotal - _discount).clamp(0.0, double.infinity);
            final tax =
            double.parse((orderSubtotal * _taxRate).toStringAsFixed(2));
            final total = (orderSubtotal + tax).clamp(0.0, double.infinity);

            return Column(
              children: [
                // المنتجات
                Flexible(
                  fit: FlexFit.loose, // ← تأخذ ارتفاعًا بقدر المحتوى فقط
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    itemCount: items.length,
                    shrinkWrap: true, // ← مهمة لتقليص الارتفاع
                    physics:
                    const NeverScrollableScrollPhysics(), // ← منع سكرول داخلي
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final it = items[i];
                      final p = it.product;
                      return Container(
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
                                      const Icon(Icons.star_rounded,
                                          color: Colors.amber, size: 16),
                                      const SizedBox(width: 4),
                                      Text(p.rating.toStringAsFixed(1),
                                          style: const TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
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

                // Apply Coupon
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
                          'apply', // ← كما طلبت (lowercase)
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),

                // ======= الجزء السفلي (مطابق للصورة) =======
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
                      _priceRow('Subtotal:',
                          '${orderSubtotal.toStringAsFixed(2)} JD'),
                      _priceRow('Tax:', '${tax.toStringAsFixed(2)} JD'),
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 6),
                      Row(
                        children: const [
                          Text('Order Total',
                              style: TextStyle(
                                  color: kTextDark,
                                  fontWeight: FontWeight.w700)),
                          Spacer(),
                        ],
                      ),
                      Row(
                        children: [
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

                // الأزرار: Proceed / Cancel
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
                                  orderSubtotal: orderSubtotal,
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
