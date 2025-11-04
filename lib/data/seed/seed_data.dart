// lib/data/seed/seed_data.dart
import '../repositories/firestore_repos.dart';

Future<void> seedSampleData() async {
  // متجر
  await StoreRepo.createStore(
    id: 'store_bean',
    name: 'Bean & Brew',
    categories: ['Food', 'Coffee'],
    logoUrl: 'https://picsum.photos/seed/bean/200/200',
    rating: 4.7,
    isOpen: true,
  );

  // منتجين
  final espressoId = await ProductRepo.createProduct(
    storeId: 'store_bean',
    name: 'Espresso Pack',
    category: 'Food',
    price: 6.5,
    imageUrls: ['https://picsum.photos/seed/espresso/600/400'],
    rating: 4.6,
  );

  await ProductRepo.createProduct(
    storeId: 'store_bean',
    name: 'Latte Beans',
    category: 'Food',
    price: 9.9,
    imageUrls: ['https://picsum.photos/seed/latte/600/400'],
    rating: 4.5,
  );

  // مثال إضافة للويش لِست لاحقاً:
  // await UserRepo.addToWishlist(uid, espressoId);
}
