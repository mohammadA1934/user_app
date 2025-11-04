import 'package:flutter/foundation.dart';

enum OrderStatus { pending, complete, cancelled }

class OrderItem {
  final String title;
  final int qty;
  final double price; // سعر القطعة الواحدة

  const OrderItem({required this.title, required this.qty, required this.price});

  double get lineTotal => qty * price;
}

class Order {
  final String id;                // مثل #1234
  OrderStatus status;
  final DateTime createdAt;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.items,
  });

  double get subtotal =>
      items.fold(0.0, (sum, it) => sum + it.lineTotal);

  double get tax => (subtotal * 0.07); // مثال: 7% ضريبة
  double get total => subtotal + tax;
}

/// مستودع بسيط بالميموري لإدارة الطلبات
class OrdersRepo extends ChangeNotifier {
  OrdersRepo._();
  static final OrdersRepo instance = OrdersRepo._();

  final List<Order> _orders = [
    Order(
      id: '1234',
      status: OrderStatus.pending,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      items: const [
        OrderItem(title: 'Spanish Latte', qty: 1, price: 2.50),
        OrderItem(title: 'Cookie', qty: 2, price: 1.00),
      ],
    ),
    Order(
      id: '1233',
      status: OrderStatus.complete,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      items: const [
        OrderItem(title: 'Turkish Coffee', qty: 1, price: 2.00),
        OrderItem(title: 'Croissant', qty: 2, price: 3.00),
        OrderItem(title: 'Cookie', qty: 4, price: 1.00),
      ],
    ),
  ];

  List<Order> get orders => List.unmodifiable(_orders);

  void cancel(String id) {
    final i = _orders.indexWhere((o) => o.id == id);
    if (i == -1) return;
    // فقط الـ pending يُلغى
    if (_orders[i].status == OrderStatus.pending) {
      _orders[i].status = OrderStatus.cancelled;
      notifyListeners();
    }
  }

  void add(Order order) {
    _orders.insert(0, order);
    notifyListeners();
  }
}
