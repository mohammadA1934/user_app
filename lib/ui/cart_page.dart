import 'package:flutter/material.dart';
import '../data/cart_repo.dart';
import 'checkout_page.dart'; // ← جديد
import 'rating_display.dart'; // ✅ الاستيراد الجديد
// تأكدي أن هذا المسار صحيح: import 'rating_display.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  static const kPrimary = Color(0xFF34D399);
  static const kTextDark = Color(0xFF222222);
  static const kHint = Color(0xFF9AA0A6);
  static const kBorder = Color(0xFFE5E7EB);

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
        elevation: .5,
        backgroundColor: Colors.white,
        title: const Text(
          'Shopping Cart',
          style: TextStyle(color: kTextDark, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: CartRepo.instance,
          builder: (_, __) {
            final items = CartRepo.instance.items;
            if (items.isEmpty) {
              return const Center(
                child: Text('Your cart is empty', style: TextStyle(color: kHint)),
              );
            }
            return Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _CartItemCard(item: items[i]),
                  ),
                ),
                _TotalBar(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({required this.item});
  final CartItem item;

  static const kTextDark = CartPage.kTextDark;
  static const kHint = CartPage.kHint;
  static const kBorder = CartPage.kBorder;
  static const kPrimary = CartPage.kPrimary;

  @override
  Widget build(BuildContext context) {
    final p = item.product;
    return Material(
      color: Colors.white,
      elevation: .5,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // صورة
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    p.image,
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(width: 96, height: 96, color: Colors.grey[200]),
                  ),
                ),
                const SizedBox(width: 12),
                // معلومات
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: kTextDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // ❌ الكود القديم: كان هنا نص فقط 'p.rating.toStringAsFixed(1)'

                          // ✅ الكود الجديد: استخدام RatingDisplay
                          RatingDisplay(
                            avgRating: item.avgRating,
                            ratingsCount: item.ratingsCount,
                            starSize: 18,
                            textSize: 14,
                          ),

                          // const SizedBox(width: 6), // تم دمج هذه المساحات داخل RatingDisplay
                          // Text(p.rating.toStringAsFixed(1), style: const TextStyle(color: kHint)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // سعر واحد + عدد
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: kBorder),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${p.price.toStringAsFixed(2)} JD',
                              style: const TextStyle(
                                  color: kTextDark, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const Spacer(),
                          _QtyStepper(item: item),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Remove',
                            onPressed: () => CartRepo.instance.remove(p.id),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Total Order (n) : xx JD
            Row(
              children: [
                Text('Total Order (${item.qty})  :',
                    style: const TextStyle(color: kHint)),
                const Spacer(),
                Text('${item.lineTotal.toStringAsFixed(2)} JD',
                    style: const TextStyle(
                        color: kTextDark, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.item});
  final CartItem item;

  static const kBorder = CartPage.kBorder;
  static const kTextDark = CartPage.kTextDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _btn(Icons.remove, () => CartRepo.instance.decrement(item.product.id)),
          SizedBox(
            width: 36,
            child: Center(
              child: Text('${item.qty}',
                  style: const TextStyle(
                      color: kTextDark, fontWeight: FontWeight.w700)),
            ),
          ),
          _btn(Icons.add, () => CartRepo.instance.increment(item.product.id)),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class _TotalBar extends StatelessWidget {
  static const kPrimary = CartPage.kPrimary;
  static const kTextDark = CartPage.kTextDark;

  @override
  Widget build(BuildContext context) {
    final total = CartRepo.instance.totalAmount;
    final qty = CartRepo.instance.totalQty;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: CartPage.kBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              Text('Total ($qty items):',
                  style: const TextStyle(color: kTextDark)),
              const Spacer(),
              Text('${total.toStringAsFixed(2)} JD',
                  style: const TextStyle(
                      color: kTextDark, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                // ✅ الانتقال إلى CheckoutPage
                if (CartRepo.instance.items.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Your cart is empty')),
                  );
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CheckoutPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Proceed to Checkout',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}