import 'package:flutter/foundation.dart';
import 'models.dart';

/// Singleton reactive cart state.
class CartState {
  CartState._();
  static final CartState instance = CartState._();

  final ValueNotifier<List<CartItem>> itemsNotifier = ValueNotifier([]);
  final ValueNotifier<String> paymentMethodNotifier = ValueNotifier('cash');

  List<CartItem> get items => itemsNotifier.value;
  String get paymentMethod => paymentMethodNotifier.value;
  int    get itemCount  => items.fold(0, (s, i) => s + i.quantity);
  double get cartTotal  => items.fold(0, (s, i) => s + i.lineTotal);

  void addToCart(CartItem item) {
    final list = List<CartItem>.from(items);
    final idx  = list.indexWhere((e) => e.productId == item.productId);
    if (idx != -1) {
      list[idx] = list[idx].copyWith(quantity: list[idx].quantity + 1);
    } else {
      list.add(item);
    }
    itemsNotifier.value = list;
  }

  void updateQuantity(int productId, int delta) {
    final list = List<CartItem>.from(items);
    final idx  = list.indexWhere((e) => e.productId == productId);
    if (idx == -1) return;
    final newQty = list[idx].quantity + delta;
    if (newQty <= 0) {
      list.removeAt(idx);
    } else {
      list[idx] = list[idx].copyWith(quantity: newQty);
    }
    itemsNotifier.value = list;
  }

  void removeFromCart(int productId) {
    itemsNotifier.value = items.where((e) => e.productId != productId).toList();
  }

  void clearCart() => itemsNotifier.value = [];
}
