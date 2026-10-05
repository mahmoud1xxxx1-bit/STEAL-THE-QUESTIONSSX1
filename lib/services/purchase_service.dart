import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class SubscriptionPurchasePayloadV2 {
  const SubscriptionPurchasePayloadV2({
    required this.productId,
    required this.purchaseId,
    required this.source,
    required this.serverVerificationData,
    required this.localVerificationData,
  });

  final String productId;
  final String? purchaseId;
  final String source;
  final String serverVerificationData;
  final String localVerificationData;
}

/// Store client for the V2 monthly subscription.
///
/// This service only starts/restores the platform purchase and exposes the
/// signed purchase payload. It never unlocks subscription features locally.
/// Entitlement remains server-authoritative through purchaseEntitlementsV2.
class MonthlySubscriptionPurchaseServiceV2 {
  static const String productId = 'monthly_subscription_v2';

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
      } else if (response.notFoundIDs.contains(productId) ||
          response.productDetails.isEmpty) {
        storeError = 'PRODUCT_NOT_CONFIGURED';
      } else {
        product = response.productDetails.first;
      }
      return product;
    } catch (error) {
      storeError = error.toString();
      return null;
    }
  }

  Future<bool> buy() async {
    final details = product ?? await loadProduct();
    if (details == null) return false;
    return _store.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: details),
    );
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

  SubscriptionPurchasePayloadV2 payloadFor(PurchaseDetails purchase) {
    return SubscriptionPurchasePayloadV2(
      productId: purchase.productID,
      purchaseId: purchase.purchaseID,
      source: purchase.verificationData.source,
      serverVerificationData: purchase.verificationData.serverVerificationData,
      localVerificationData: purchase.verificationData.localVerificationData,
    );
  }

  void listen({
    required Future<bool> Function(
      SubscriptionPurchasePayloadV2 payload,
    ) onVerifiedByServer,
  }) {
    _subscription ??= _store.purchaseStream.listen((items) async {
      for (final purchase in items) {
        if (purchase.status != PurchaseStatus.purchased &&
            purchase.status != PurchaseStatus.restored) {
          continue;
        }

        final accepted = await onVerifiedByServer(payloadFor(purchase));
        if (accepted && purchase.pendingCompletePurchase) {
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
