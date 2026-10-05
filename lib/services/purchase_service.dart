import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class WeeklyPassPurchaseService {
  static const productId = 'weekly_pass_v1';

  final InAppPurchase _store = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  Future<List<ProductDetails>> loadProducts() async {
    if (kIsWeb) return const [];
    if (!await _store.isAvailable()) return const [];
    final response = await _store.queryProductDetails({productId});
    return response.productDetails;
  }

  Future<bool> buy() async {
    final products = await loadProducts();
    if (products.isEmpty) return false;
    return _store.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: products.first),
    );
  }

  void listen({
    required Future<void> Function(PurchaseDetails purchase) onPurchase,
  }) {
    _subscription ??= _store.purchaseStream.listen((items) async {
      for (final purchase in items) {
        await onPurchase(purchase);
        if (purchase.pendingCompletePurchase) {
          await _store.completePurchase(purchase);
        }
      }
    });
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
