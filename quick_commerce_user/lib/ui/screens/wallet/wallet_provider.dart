import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di/repository_providers.dart';
import '../../../domain/model/user.dart';

final walletProvider = FutureProvider.autoDispose<Wallet>((ref) async {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.wallet();
});
