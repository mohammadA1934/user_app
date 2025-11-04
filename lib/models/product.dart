class Product {
  final String id;
  final String title;
  final String desc;
  final double price;
  final String image;
  final double rating;
  final int reviews;
  final List<String> sizes; // مثل: ["S","M","L"]

  const Product({
    required this.id,
    required this.title,
    required this.desc,
    required this.price,
    required this.image,
    required this.rating,
    required this.reviews,
    this.sizes = const ["S", "M", "L"],
  });
}
