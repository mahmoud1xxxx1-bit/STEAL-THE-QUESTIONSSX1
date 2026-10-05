import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class WeeklyPassPurchaseService {
  static const String productId = 'weekly_pass_v1';

  final InAppPurchase _store = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  ProductDetails? product;
  bool storeAvailable = false;
  String? storeError;

  Future<ProductDetails?> loadProduct() async {
    storeError = null;
    product = null;

    if (kIsWeb) {
      storeError = 'WEB_UNSUPPORTED';
      return null;
    }

    try {
      storeAvailable = await _store.isAvailable();
      if (!storeAvailable) {
        storeError = 'STORE_UNAVAILABLE';
        return null;
      }

      final response = await _store.queryProductDetails({productId});
      if (response.error != null) {
        storeError = response.error!.message;
      } else if (response.notFoundIDs.contains(productId)) {
        storeError = 'PRODUCT_NOT_CONFIGURED';
      } else if (response.productDetails.isEmpty) {
        storeError = 'PRODUCT_NOT_CONFIGURED';
      } else {
        product = response.productDetails.first;
      }
      return product;
    } catch (e) {
      storeError = e.toString();
      return null;
    }
  }

  Future<bool> buy() async {
    final details = product ?? await loadProduct();
    if (details == null) return false;

    final purchaseParam = PurchaseParam(productDetails: details);
    return _store.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<bool> restorePurchases() async {
    if (kIsWeb) return false;
    if (!storeAvailable) {
      await loadProduct();
    }
    if (!storeAvailable) return false;
    await _store.restorePurchases();
    return true;
  }

  void listen({
    required Future<bool> Function(PurchaseDetails purchase) onPurchase,
  }) {
    _subscription ??= _store.purchaseStream.listen((items) async {
      for (final purchase in items) {
        final delivered = await onPurchase(purchase);
        if (delivered &&
            purchase.pendingCompletePurchase &&
            (purchase.status == PurchaseStatus.purchased ||
                purchase.status == PurchaseStatus.restored)) {
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
