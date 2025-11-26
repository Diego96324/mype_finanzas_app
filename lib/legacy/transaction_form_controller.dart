import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/category_providers.dart';
import '../models/dtos/category_model.dart';
import '../models/services/last_category_storage.dart';
import 'transaction_form_state.dart';

final lastCategoryStorageProvider = Provider<LastCategoryStorage>((ref) => LastCategoryStorage());

// Provider que expone la última categoría para el usuario/tipo
final lastCategoryFutureProvider = FutureProvider.family<int?, LastCategoryKey>((ref, key) async {
  final storage = ref.read(lastCategoryStorageProvider);
  return storage.readLast(key.userId, tipo: key.tipo);
});

class LastCategoryKey {
  final int userId;
  final String? tipo;
  const LastCategoryKey({required this.userId, this.tipo});
}

final transactionFormControllerProvider = StateNotifierProvider.autoDispose
    .family<TransactionFormController, TransactionFormState, TransactionFormArgs>((ref, args) {
  return TransactionFormController(ref, args);
});

class TransactionFormArgs extends Equatable {
  final int userId;
  final bool isQuickAdd;
  final bool isEditing;
  final int? initialCategoryId; // si edición
  final String tipo; // ingreso | egreso | transferencia
  const TransactionFormArgs({
    required this.userId,
    required this.tipo,
    this.isQuickAdd = false,
    this.isEditing = false,
    this.initialCategoryId,
  });

  @override
  List<Object?> get props => [userId, tipo, isQuickAdd, isEditing, initialCategoryId];
}

class TransactionFormController extends StateNotifier<TransactionFormState> {
  final Ref ref;
  final TransactionFormArgs args;
  List<Category> _categoriesCache = const [];
  TransactionFormController(this.ref, this.args)
      : super(TransactionFormState.initial(isEditing: args.isEditing));

  Future<void> init() async {
    if (args.isEditing) {
      state = state.copyWith(
        selectedCategoryId: args.initialCategoryId,
        isCategoryAutofilled: false,
        focusTarget: FocusTarget.none,
      );
      return;
    }

    // precargar categorías activas para heurísticas y validación
    _categoriesCache = await ref.read(categoriesStateProvider.future);

    final lastId = await ref.read(lastCategoryStorageProvider).readLast(args.userId, tipo: args.tipo);
    if (lastId != null) {
      final cat = _findInCache(lastId);
      if (cat != null && cat.activa) {
        state = state.copyWith(
          selectedCategoryId: lastId,
          isCategoryAutofilled: true,
          focusTarget: _initialFocusAutofilled(),
        );
        return;
      } else {
        // limpiar preferencia inválida
        await ref.read(lastCategoryStorageProvider).clear(args.userId, tipo: args.tipo);
      }
    }

    // Sin autofill válido
    state = state.copyWith(focusTarget: _initialFocusNoAutofill());
  }

  FocusTarget _initialFocusAutofilled() {
    // Si es quickAdd vamos directo a monto, si no quizá dejamos sin foco para que usuario revise
    return args.isQuickAdd ? FocusTarget.monto : FocusTarget.monto;
  }

  FocusTarget _initialFocusNoAutofill() {
    // QuickAdd: primero categoría para seleccionar, luego salta
    return FocusTarget.categoria;
  }

  Future<void> onSubmitSuccess() async {
    final catId = state.selectedCategoryId;
    if (catId != null && !args.isEditing) {
      await ref.read(lastCategoryStorageProvider).writeLast(args.userId, catId, tipo: args.tipo);
    }
  }

  void onCategoryChanged(int? categoryId) {
    final wasAutofilled = state.isCategoryAutofilled;
    state = state.copyWith(
      selectedCategoryId: categoryId,
      isCategoryAutofilled: false,
      focusTarget: wasAutofilled ? FocusTarget.none : FocusTarget.monto,
    );
  }

  void onAmountChanged(double? value) {
    state = state.copyWith(amount: value);
  }

  void onAmountSubmitted() {
    final amt = state.amount ?? 0;
    final catId = state.selectedCategoryId;
    final shouldGoNotes = _shouldJumpToNotes(amt, catId);
    state = state.copyWith(focusTarget: shouldGoNotes ? FocusTarget.notas : FocusTarget.etiquetas);
  }

  void onNotesChanged(String value) {
    state = state.copyWith(notes: value);
  }

  void onTagsChanged(String value) {
    final normalized = _normalizeTags(value);
    state = TransactionFormState(
      selectedCategoryId: state.selectedCategoryId,
      isCategoryAutofilled: state.isCategoryAutofilled,
      focusTarget: state.focusTarget,
      amount: state.amount,
      notes: state.notes,
      tags: normalized,
      isEditing: state.isEditing,
    );
  }

  List<String> _normalizeTags(String raw) {
    return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  Category? _findInCache(int id) {
    for (final c in _categoriesCache) {
      if (c.id == id) return c;
      for (final s in c.subcategorias ?? []) {
        if (s.id == id) return s;
      }
    }
    return null;
  }

  bool _shouldJumpToNotes(double amount, int? catId) {
    const threshold = 1000.0;
    if (amount >= threshold) return true;
    if (catId == null) return false;
    final cat = _findInCache(catId);
    if (cat == null) return false;
    final nombreLower = (cat.nombre).toLowerCase();
    const requiringKeywords = ['servicio', 'servicios', 'salud', 'med', 'educ', 'impuesto', 'tax'];
    if (args.tipo == 'egreso' && requiringKeywords.any((k) => nombreLower.contains(k))) {
      return true;
    }
    return false;
  }
}
