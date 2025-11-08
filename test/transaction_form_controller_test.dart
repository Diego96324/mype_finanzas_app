import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mype_finanzas/features/transactions/application/transaction_form_controller.dart';
import 'package:mype_finanzas/features/transactions/domain/transaction_form_state.dart';
import 'package:mype_finanzas/core/providers/category_providers.dart';
import 'package:mype_finanzas/data/models/category_model.dart';

// Fake categories provider override
final _fakeCategories = [
  Category(
    id: 1,
    usuarioId: 1,
    categoriaPadreId: null,
    nombre: 'Servicios',
    tipo: 'egreso',
    descripcion: 'Pago de servicios',
    icono: 'services',
    color: '#FF0000',
    activa: true,
    esPredeterminada: false,
    orden: 0,
    tipoNegocio: null,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    subcategorias: [],
  ),
  Category(
    id: 2,
    usuarioId: 1,
    categoriaPadreId: null,
    nombre: 'Alimentos',
    tipo: 'egreso',
    descripcion: 'Comida',
    icono: 'food',
    color: '#00FF00',
    activa: true,
    esPredeterminada: false,
    orden: 1,
    tipoNegocio: null,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    subcategorias: [],
  ),
  Category(
    id: 3,
    usuarioId: 1,
    categoriaPadreId: null,
    nombre: 'Salud',
    tipo: 'egreso',
    descripcion: 'Salud',
    icono: 'health',
    color: '#0000FF',
    activa: true,
    esPredeterminada: false,
    orden: 2,
    tipoNegocio: null,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    subcategorias: [],
  ),
];

// Fake AsyncNotifier para categoriesStateProvider
class FakeCategoriesState extends CategoriesState {
  final List<Category> data;
  FakeCategoriesState(this.data);
  @override
  Future<List<Category>> build() async => data;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TransactionFormController', () {
    ProviderContainer makeContainer({Map<String, Object> prefs = const {}}) {
      SharedPreferences.setMockInitialValues(prefs);
      final container = ProviderContainer(overrides: [
        categoriesStateProvider.overrideWith(() => FakeCategoriesState(_fakeCategories)),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    test('init con autofill válido establece categoría y foco monto', () async {
      final container = makeContainer(prefs: {'last_category_id_1_egreso': 2});
      final controller = container.read(
        transactionFormControllerProvider(
          TransactionFormArgs(userId: 1, tipo: 'egreso'),
        ).notifier,
      );
      await controller.init();
      final state = container.read(
        transactionFormControllerProvider(TransactionFormArgs(userId: 1, tipo: 'egreso')),
      );
      expect(state.selectedCategoryId, 2);
      expect(state.isCategoryAutofilled, true);
      expect(state.focusTarget, FocusTarget.monto);
    });

    test('init sin preferencia válida enfoca categoría', () async {
      final container = makeContainer();
      final controller = container.read(
        transactionFormControllerProvider(TransactionFormArgs(userId: 1, tipo: 'egreso')).notifier,
      );
      await controller.init();
      final state = container.read(
        transactionFormControllerProvider(TransactionFormArgs(userId: 1, tipo: 'egreso')),
      );
      expect(state.selectedCategoryId, isNull);
      expect(state.isCategoryAutofilled, false);
      expect(state.focusTarget, FocusTarget.categoria);
    });

    test('onAmountSubmitted salta a notas si monto >= 1000', () async {
      final container = makeContainer();
      final args = TransactionFormArgs(userId: 1, tipo: 'egreso');
      final controller = container.read(transactionFormControllerProvider(args).notifier);
      await controller.init();
      controller.onAmountChanged(1500);
      controller.onAmountSubmitted();
      final state = container.read(transactionFormControllerProvider(args));
      expect(state.focusTarget, FocusTarget.notas);
    });

    test('onAmountSubmitted salta a notas por heurística egreso (Servicios)', () async {
      final container = makeContainer();
      final args = TransactionFormArgs(userId: 1, tipo: 'egreso');
      final controller = container.read(transactionFormControllerProvider(args).notifier);
      await controller.init();
      controller.onCategoryChanged(1); // Servicios
      controller.onAmountChanged(100); // < threshold
      controller.onAmountSubmitted();
      final state = container.read(transactionFormControllerProvider(args));
      expect(state.focusTarget, FocusTarget.notas);
    });

    test('onSubmitSuccess guarda preferencia', () async {
      final container = makeContainer();
      final args = TransactionFormArgs(userId: 1, tipo: 'egreso');
      final controller = container.read(transactionFormControllerProvider(args).notifier);
      await controller.init();
      controller.onCategoryChanged(2);
      await controller.onSubmitSuccess();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('last_category_id_1_egreso'), 2);
    });

    test('edición no guarda preferencia', () async {
      final container = makeContainer(prefs: {'last_category_id_1_egreso': 2});
      final args = TransactionFormArgs(userId: 1, tipo: 'egreso', isEditing: true, initialCategoryId: 3);
      final controller = container.read(transactionFormControllerProvider(args).notifier);
      await controller.init();
      await controller.onSubmitSuccess();
      final prefs = await SharedPreferences.getInstance();
      // debería seguir siendo la preferencia inicial (2) porque edición no escribe
      expect(prefs.getInt('last_category_id_1_egreso'), 2);
    });
  });
}
