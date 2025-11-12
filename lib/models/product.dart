class Product {
  final String id;
  final String title;
  final String desc;
  final double price;
  final String image;

  final List<String> sizes; // مثل: ["S","M","L"]
final String storeId;
final double avgRating;
final int ratingsCount;
  const Product({
    required this.id,
    required this.title,
    required this.desc,
    required this.price,
    required this.image,

    required this.storeId,

    this.sizes = const ["S", "M", "L"],
    this.avgRating=0.0, this.ratingsCount=0

  });


// 💡 هذه هي دالة الـ factory الضرورية التي يجب إضافتها:
factory Product.fromMap(Map<String, dynamic> map, String id) {
return Product(
id: id,
storeId: (map['storeId'] ?? '').toString(),

title: (map['title'] ?? 'Product').toString(),
desc: (map['description'] ?? map['desc'] ?? '').toString(),
price: (map['price'] as num? ?? 0.0).toDouble(),
image: (map['imageUrl'] ?? map['image'] ?? '').toString(),
sizes: (map['sizes'] is List)
? List<String>.from(map['sizes'] as List)
    : const <String>[],

// ✅ قراءة حقول التقييم المتوسطة بشكل حصري
avgRating: (map['avgRating'] as num? ?? 0.0).toDouble(),
ratingsCount: (map['ratingsCount'] as num? ?? 0).toInt(),

// ❌ تأكدي من عدم وجود أي قراءة لـ map['rating'] أو map['reviews'] هنا
);
}}
