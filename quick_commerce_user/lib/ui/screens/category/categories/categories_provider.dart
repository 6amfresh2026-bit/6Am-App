import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../di/repository_providers.dart';
import '../../../../domain/model/category.dart';

/// All top-level categories, from the admin-curated list.
final categoriesProvider = FutureProvider<List<Category>>(
  (ref) => ref.watch(categoryRepositoryProvider).topLevel(),
);
