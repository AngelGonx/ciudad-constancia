import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../game/game_state.dart';

/// Compra única de la ciudad (logros y cosméticos incluidos) con Google Play.
///
/// En Play Console hay que crear un producto integrado (pago único) con el id
/// [productId] y precio de 1 USD. Las compras solo funcionan cuando la app se
/// instala desde Google Play (por ejemplo, desde una prueba interna).
class Store extends ChangeNotifier {
  static const String productId = 'ciudad_constancia';
  static final Store instance = Store._();
  Store._();

  bool available = false;
  ProductDetails? product;
  bool busy = false;
  String? error;
  GameState? _game;

  Future<void> init(GameState game) async {
    _game = game;
    try {
      final iap = InAppPurchase.instance;
      iap.purchaseStream.listen(_onPurchases, onError: (Object e) {
        busy = false;
        error = '$e';
        notifyListeners();
      });
      available = await iap.isAvailable();
      if (available) {
        final resp = await iap.queryProductDetails({productId});
        if (resp.productDetails.isNotEmpty) product = resp.productDetails.first;
        // Si ya se compró antes (otro teléfono o reinstalación), se recupera.
        await iap.restorePurchases();
      }
    } catch (_) {
      available = false;
    }
    notifyListeners();
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID == productId) {
        switch (p.status) {
          case PurchaseStatus.pending:
            busy = true;
            break;
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            _game?.setCityPurchased(true);
            busy = false;
            error = null;
            break;
          case PurchaseStatus.error:
            busy = false;
            error = p.error?.message;
            break;
          case PurchaseStatus.canceled:
            busy = false;
            break;
        }
      }
      if (p.pendingCompletePurchase) {
        try {
          await InAppPurchase.instance.completePurchase(p);
        } catch (_) {}
      }
    }
    notifyListeners();
  }

  bool get canBuy => available && product != null && !busy;

  Future<void> buy() async {
    final prod = product;
    if (prod == null) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await InAppPurchase.instance.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: prod));
    } catch (e) {
      busy = false;
      error = '$e';
      notifyListeners();
    }
  }

  Future<void> restore() async {
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (_) {}
  }
}
