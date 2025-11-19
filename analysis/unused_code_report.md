# Informe automático de código sin referencias

Fecha: 2025-11-17

Este informe fue generado automáticamente (herramientas: dart_code_metrics, flutter analyze y búsquedas heurísticas) para identificar archivos/clases/servicios que parecen no ser referenciados en `lib/`.

## Resumen rápido

- Archivos claramente no referenciados (candidatos fuertes a eliminación o a marcar como obsoletos):
  - `lib/domain/services/analytics_service.dart` (archivo vacío / placeholder)
  - `lib/domain/services/theme_service.dart` (servicio en desarrollo; no utilizado — proyecto usa Riverpod `themeStateProvider` en su lugar)
  - `lib/domain/services/secure_storage_service.dart` (clase disponible, pero el provider `secureStorageServiceProvider` existe en `core/providers/providers.dart`; se recomienda revisar usos)
  - `lib/domain/services/transaction_cache_service.dart` (sí es usado en `transactions_controller`, confirmar)

- Servicios que sí aparecen usados o expuestos vía providers/tests:
  - `GamificationService` (usado por providers/tests)
  - `BackupService` (usado en `main.dart`)
  - `AuthService` (usado ampliamente)
  - `CategoryBudgetService` (usado en UI y tests)

## Recomendaciones concretas (rápidas, 1 día)

1. `analytics_service.dart`: eliminar o implementar. Hoy lo marqué con un comentario; si no lo necesitas, elimina este archivo y corre `flutter analyze`.
2. `theme_service.dart`: es un servicio stateful que duplica la lógica de `themeStateProvider`. Decide una única fuente de verdad:
   - Si prefieres Riverpod, elimina `ThemeService` y usa `themeStateProvider` (ya existe).
   - Si prefieres `ThemeService`, adapta providers para exponerlo y eliminar `themeStateProvider`.
3. `secure_storage_service.dart`: está definido y existe un provider; no eliminar. Confirmar si existen duplicados (`data/datasources/local/secure_storage.dart`) y unificar.
4. Ejecutar `dart_code_metrics` (actualmente instalado localmente) y usar herramientas de análisis para detectar imports no usados (por ejemplo `dart pub global activate unused` si se requiere). Ya se aplicaron fixes automáticos con `dart fix --apply`.

## Pasos sugeridos para hoy (implementación)

1. Crear rama `cleanup/unused-code`.
2. Eliminar `analytics_service.dart` o mantenerlo con el comentario (ya hecho). Recomiendo eliminar en una PR separada.
3. Sustituir/Eliminar `ThemeService` si decides usar Riverpod (pequeño cambio en `app.dart` para usar provider existente).
4. Ejecutar `flutter analyze` y `flutter test` y corregir fallos.

---

Si quieres, puedo aplicar automáticamente las siguientes acciones ahora:
- Eliminar `analytics_service.dart` en una rama nueva.
- Reemplazar el uso de tema (si confirmas que quieres Riverpod como fuente de verdad) eliminando `theme_service.dart` y actualizando `providers.dart`.
- Ejecutar `flutter analyze` y `flutter test` y entregarte el reporte con errores (si los hay).

Dime cuál de las acciones anteriores quieres que ejecute y lo hago ahora.
