import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'home_page.dart';
import 'wishlist_page.dart';
import 'cart_page.dart';
import 'profile_settings_page.dart';

class MyOrdersPage extends StatelessWidget {
  const MyOrdersPage({super.key});

  static const kPrimary = Color(0xFF34D399);
  static const kTextDark = Color(0xFF222222);
  static const kHint = Color(0xFF9AA0A6);
  static const kBorder = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: const _BottomBar(),
      body: SafeArea(
        child: Column(
          children: [
            _header(context),
            const SizedBox(height: 8),
            if (uid == null)
              const Expanded(
                child: Center(
                  child: Text('Please sign in to see your orders',
                      style: TextStyle(color: kHint)),
                ),
              )
            else
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('orders')
                      .where('customerUid', isEqualTo: uid)
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
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(
                        child:
                        Text('No orders yet', style: TextStyle(color: kHint)),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final d = docs[i].data();
                        final id = docs[i].id;
                        final status = (d['status'] ?? 'pending').toString();
                        final total = (d['total'] is num)
                            ? (d['total'] as num).toDouble()
                            : 0.0;
                        final items = (d['items'] as List? ?? [])
                            .map((e) => _OrderItemView.fromMap(e))
                            .toList();

                        return _OrderCardFS(
                          orderId: id,
                          status: status,
                          total: total,
                          items: items,
                        );
                      },
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
            tooltip: 'Back to Home',
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomePage()),
                  (r) => false,
            ),
          ),
          const Expanded(
            child: Text(
              'My Orders',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kTextDark,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _OrderItemView {
  final String title;
  final int qty;
  final double price;
  double get lineTotal => price * qty;

  _OrderItemView({required this.title, required this.qty, required this.price});

  factory _OrderItemView.fromMap(dynamic m) {
    final map = (m as Map?) ?? {};
    final price = map['price'] is num ? (map['price'] as num).toDouble() : 0.0;
    final qty = map['qty'] is num ? (map['qty'] as num).toInt() : 0;
    final title = (map['title'] ?? '').toString();
    return _OrderItemView(title: title, qty: qty, price: price);
  }
}

class _OrderCardFS extends StatelessWidget {
  const _OrderCardFS({
    required this.orderId,
    required this.status,
    required this.total,
    required this.items,
  });

  final String orderId;
  final String status; // pending | confirmed | completed | cancelled
  final double total;
  final List<_OrderItemView> items;

  Color _statusColor(String s) {
    switch (s) {
      case 'completed':
        return const Color(0xFF22C55E);
      case 'cancelled':
        return Colors.redAccent;
      case 'confirmed':
        return const Color(0xFF3B82F6);
      case 'pending':
      default:
        return const Color(0xFFFFA000); // برتقالي خفيف لـ Pending
    }
  }

  String _statusText(String s) {
    switch (s) {
      case 'completed':
        return 'Complete';
      case 'cancelled':
        return 'Cancelled';
      case 'confirmed':
        return 'Confirmed';
      case 'pending':
      default:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(status);

    return Card(
      elevation: .5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: MyOrdersPage.kBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shopping_bag_outlined, size: 28),
                const SizedBox(width: 8),
                Text(
                  'Order #$orderId',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: MyOrdersPage.kTextDark,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _statusText(status),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            const Text(
              'Items :',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: MyOrdersPage.kTextDark,
              ),
            ),
            const SizedBox(height: 8),
            ...items.map(
                  (it) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${it.title} x${it.qty}',
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ),
                    Text(
                      '${it.lineTotal.toStringAsFixed(2)} JD',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 20),

            Row(
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: MyOrdersPage.kTextDark,
                  ),
                ),
                const Spacer(),
                Text(
                  '${total.toStringAsFixed(2)} JD',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // أزرار الحالة وفق قواعد الصلاحيات للمستخدم
            if (status == 'pending')
              SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton(
                  onPressed: () => _updateStatus('cancelled'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade400,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Cancel'),
                ),
              )
            else if (status == 'confirmed')
              SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton(
                  onPressed: () => _updateStatus('completed'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Completed'),
                ),
              )
            else
              Row(
                children: [
                  Icon(
                    status == 'cancelled'
                        ? Icons.cancel_outlined
                        : Icons.check_circle_outline,
                    color: statusColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _statusText(status),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(String newStatus) async {
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .update({'status': newStatus});
  }
}

/// Bottom Bar مع زر السلة الدائري بالوسط
class _BottomBar extends StatelessWidget {
  const _BottomBar();

  static const kPrimary = MyOrdersPage.kPrimary;
  static const kBorder = MyOrdersPage.kBorder;

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
              ),
              _barItem(
                context,
                icon: Icons.favorite_border_rounded,
                label: 'Wishlist',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WishlistPage()),
                ),
              ),
              const SizedBox(width: 56), // مكان زر السلة
              _barItem(
                context,
                icon: Icons.inventory_2_outlined,
                label: 'My Orders',
                selected: true,
                onTap: () {},
              ),
              _barItem(
                context,
                icon: Icons.settings_outlined,
                label: 'Setting',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileSettingsPage()),
                ),
              ),
            ],
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
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: const Border.fromBorderSide(
                    BorderSide(color: kBorder),
                  ),

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
