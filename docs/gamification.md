Gamification - Reglas y Providers

Resumen rápido
- Versión de BD: 14
- Tablas: gamification_profiles, gamification_achievements, gamification_events
- Repositorio: `lib/data/repositories/gamification_repository.dart`
- Servicio: `lib/application/services/gamification_service.dart`
- Providers Riverpod: `lib/presentation/providers/gamification/gamification_providers.dart`

Reglas implementadas
1) Puntos por tipo de transacción
   - ingreso: 5
   - egreso: 10
   - transferencia: 2
   - default: 1
   => Puede sobreescribirse pasando `puntosOtorgados` a `recordEvent`.

2) Cálculo de nivel
   - `nivel = 1 + (puntos ~/ 500)`
   - Cambiar `pointsPerLevel` en `lib/core/constants/gamification_constants.dart` si se desea otra progresión.

3) Racha (streak)
   - Si el evento ocurre el mismo día que `ultima_fecha_evento` => la racha no cambia.
   - Si el evento ocurre al día siguiente => racha += 1.
   - Si hay gap > 1 día => racha = 1.
   - Si `ultima_fecha_evento` es null => racha = 1.

4) Logros (achievements)
   - Los logros actuales se tratan como catálogo global (tabla `gamification_achievements`).
   - Reglas ejemplo incluidas en `evaluateAchievements`:
     - `tipo == 'points'`: desbloquear cuando `progreso_objetivo <= profile.puntos`.
     - `tipo == 'streak'`: desbloquear cuando `progreso_objetivo <= profile.racha_actual`.
   - Cuando se desbloquea, se actualiza el estado del logro y se inserta un evento `achievement_unlocked`.

API del servicio
- recordEvent({ usuarioId, tipoEvento, descripcion?, fechaEvento, puntosOtorgados = 0, transactionType? })
  - Inserta `gamification_events` y actualiza el `gamification_profiles` (puntos, nivel, racha, ultima_fecha_evento).
  - Llama a `evaluateAchievements`.
- computeLevel(puntos)
- updateStreak(currentStreak, ultimaFechaEvento, fechaEvento)
- evaluateAchievements(usuarioId)
- getDashboard(usuarioId) -> { profile, events, achievements }

Providers disponibles
- `gamificationRepositoryProvider` (Provider<GamificationRepository>)
- `gamificationServiceProvider` (Provider<GamificationService>)
- `gamificationDashboardProvider` (FutureProvider.family<Map<String, dynamic>, int>)
- `gamificationEventsProvider` (FutureProvider.autoDispose.family<List<dynamic>, int>)

Integración en `TransactionsController`
- Al crear o actualizar transacciones se llama `GamificationService.recordEvent` con `transactionType` igual al `tipo` de la transacción (`ingreso`/`egreso`/`transferencia`). Esto garantiza que la suma de puntos y la actualización de racha/level se realice automáticamente.
- La llamada está implementada como `Future.microtask(...)` para no bloquear el flujo crítico de guardado/actualización.

Tests incluidos
- `test/application/gamification/gamification_service_test.dart`:
  - valida suma de puntos y cambio de nivel
  - valida actualización y reseteo de racha
  - valida desbloqueo de logro y registro del evento correspondiente

Cambios que necesita saber el otro equipo (lista completa y acciones esperadas)
- Migración y BD
  - Se subió la versión de la DB a 14 en `lib/core/database/app_database.dart`.
  - Nuevas tablas creadas en `_onCreate` y en `_onUpgrade` con `CREATE TABLE IF NOT EXISTS`:
    - `gamification_profiles(usuario_id PK, puntos, nivel, racha_actual, racha_maxima, ultima_fecha_evento, created_at, updated_at)`
    - `gamification_achievements(id, tipo, nombre, descripcion, progreso_actual, progreso_objetivo, estado, ultima_actualizacion, created_at, updated_at)`
    - `gamification_events(id, usuario_id, tipo_evento, descripcion, puntos_otorgados, fecha_evento, created_at)`
  - `ensureSeedUser()` ahora crea un perfil en `gamification_profiles` para el usuario seed (admin) si la tabla existe, para que instalaciones nuevas tengan perfil inicial.

- Repositorios / Modelos
  - Nuevos modelos en `lib/data/models/`:
    - `gamification_profile_model.dart` (toJson/fromJson)
    - `gamification_achievement_model.dart` (toJson/fromJson)
    - `gamification_event_model.dart` (toJson/fromJson)
  - Repositorio en `lib/data/repositories/gamification_repository.dart` con métodos:
    - `getProfile`, `upsertProfile`, `listAchievements`, `insertAchievement`, `updateAchievement`, `insertEvent`, `listEvents`.

- Servicio (dominio/aplicación)
  - `lib/application/services/gamification_service.dart` expone la lógica de negocio (reglas de puntos, nivel, racha, evaluación de logros y dashboard).
  - Reusar este servicio desde UI/controllers: llamar a `recordEvent` para añadir puntos/rachas y re-evaluar logros.

- Integración técnica (controladores/UI)
  - `TransactionsController` fue extendido para disparar `recordEvent` tras insertar o actualizar transacciones.
  - Providers Riverpod disponibles para inyectar el servicio/repo en UI: ver `lib/presentation/providers/gamification/gamification_providers.dart`.

- Tests y QA
  - Tests unitarios añadidos en `test/application/gamification/` (servicio) con un `FakeGamificationRepository` in-memory.
  - Ejecutar los tests nuevos con:

```bash
flutter test test/application/gamification/gamification_service_test.dart
```

- Pasos para probar la migración en un entorno local
  1. En un emulador o dispositivo, reemplazar la DB por una copia con versión 13 (si se quiere simular upgrade) o iniciar la app limpia para crear la DB en v14.
  2. Iniciar la app, revisar logs para `Migración v14 (gamification) aplicada` o comprobar tablas con SQL:

```sql
SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'gamification_%';
```

  3. Usar `GamificationRepository` o `GamificationService` desde un script/console o UI para insertar eventos y verificar `gamification_profiles` y `gamification_events`.

Puntos de atención y recomendaciones
- Logros por usuario: hoy `gamification_achievements` es catálogo global; si se requiere progreso/estado por usuario, añadir tabla `user_achievements` (v15) y adaptar `evaluateAchievements`.
- Consistencia transaccional: actualmente el registro de evento gamification es asíncrono respecto a la inserción de transacciones (no bloqueante); si prefieren garantizad transaccional, cambiar a flujo sin `microtask` y controlar errores.
- Sincronización remota: si existe backend, diseñar endpoints para sincronizar perfiles, logros y eventos; usar created_at/updated_at para resolver conflictos.

Contacto / próxima tarea sugerida
- Puedo añadir la migración v15 con `user_achievements` y adaptar tests (recomendado si los logros deben ser por usuario).
- Puedo implementar tests de integración que cubran flujo transacción -> servicio -> DB usando `':memory:'`.

Comandos útiles
- Analizar el proyecto (sintaxis):

```bash
flutter analyze
```

- Ejecutar tests (todos):

```bash
flutter test
```

- Ejecutar el test específico de gamification:

```bash
flutter test test/application/gamification/gamification_service_test.dart
```

## Integración UI y navegación (qué debe saber el equipo de la tarde)

1) Navegación desde la pantalla principal
- Revisar `lib/presentation/features/home/views/home_screen.dart` (u otro punto de entrada del menú/navbar). Añadir un botón o ítem en el menú que navegue a la ruta `/gamification`.
  - Si la app usa `Navigator` simple: usar `Navigator.of(context).pushNamed('/gamification')`.
  - Si la app usa `go_router` o `auto_route`, registrar la ruta `/gamification` en el router principal y navegar con la API correspondiente.
- Asegurarse de añadir la ruta al router/global routes para que la pantalla sea accesible desde el menú principal.

2) Pantalla `GamificationScreen`
- Revisar `lib/presentation/features/gamification/views/gamification_screen.dart`. Si no existe, crearla siguiendo el patrón de otras pantallas en `presentation/features/*/views`.
- Recomendación de layout:
  - Encabezado con puntos, nivel y racha (use `ConsumerWidget` o `HookConsumerWidget`).
  - Sección de logros: tarjetas que reciben `List<GamificationAchievementModel>` del provider de achievements.
  - Lista de eventos recientes: `ListView` o `SliverList` usando `gamificationEventsProvider`.
- Consumir los providers definidos en `lib/presentation/providers/gamification/gamification_providers.dart` (`gamificationDashboardProvider`, `gamificationEventsProvider`) para poblar la UI.

3) Integración en `TransactionsController`
- Revisar `lib/presentation/features/transactions/controllers/transactions_controller.dart` (o el controller equivalente donde se guardan/actualizan transacciones).
- Tras crear o actualizar una transacción, invocar `gamificationService.recordEvent(...)` suministrando al menos:
  - `usuarioId` (el id del usuario que hace la transacción)
  - `tipoEvento` (por ejemplo `transaction` o `transaction_saved`)
  - `transactionType` (el tipo de transacción: `ingreso`, `egreso`, `transferencia`) — esto permite que la función compute los puntos según las reglas.
- Implementación recomendada: llamar la API sin bloquear el flujo principal, por ejemplo con `Future.microtask(() => gamificationService.recordEvent(...))` o usando `unawaited(...)` si se usa `pedantic`/`flutter_lints`.
- Verificar manejo de errores: registrar errores en logs pero no impedir que la operación de transacción finalice correctamente.

4) Providers y consumo por la UI
- Providers disponibles (ver `lib/presentation/providers/gamification/gamification_providers.dart`):
  - `gamificationRepositoryProvider` (Provider<GamificationRepository>)
  - `gamificationServiceProvider` (Provider<GamificationService>)
  - `gamificationDashboardProvider` (FutureProvider.family<Map<String, dynamic>, int>)
  - `gamificationEventsProvider` (FutureProvider.autoDispose.family<List<GamificationEventModel>, int>)
- Buenas prácticas: en widgets usar `.when()` o `ref.watch(...).when(...)` para manejar loading/data/error.

## Tests widget y de integración UI (qué necesita el equipo de la tarde)

1) Tests widget básicos
- Añadir/Completar `test/presentation/gamification/gamification_screen_test.dart` con pruebas que:
  - Rendericen `GamificationScreen` con providers mockeados (usar `ProviderScope(overrides: [...])`).
  - Verifiquen la presencia del encabezado (texto con puntos/nivel/racha), al menos una tarjeta de logro y al menos un evento en la lista.
  - Usar `flutter_test` y `hooks_riverpod` (o `flutter_riverpod`) según el resto del proyecto.
- Placeholder sugerido (para que el equipo complete): crear `FakeGamificationRepository` o overrides que devuelvan datos estáticos para `gamificationDashboardProvider` y `gamificationEventsProvider`.

2) Tests de servicios y controllers
- Revisar `test/application/gamification/` (ya contiene tests unitarios del servicio). Añadir tests para `TransactionsController` que verifiquen que tras guardar/actualizar una transacción se llama `gamificationService.recordEvent` (mockear el servicio y verificar la interacción).

3) Estructura de tests recomendada
- `test/presentation/gamification/gamification_screen_test.dart` (widget tests)
- `test/application/gamification/gamification_service_test.dart` (unit tests del servicio) — ya incluido
- `test/application/gamification/transactions_controller_gamification_test.dart` (unit test que verifica integración con controller)

## Pasos para ejecutar análisis y tests (rápido)
- Analizar el proyecto:

```bash
flutter analyze
```

- Ejecutar todos los tests:

```bash
flutter test
```

- Ejecutar sólo los widget tests de gamification:

```bash
flutter test test/presentation/gamification/gamification_screen_test.dart
```

> Nota: en Windows usar los comandos en `cmd.exe` o PowerShell según tu preferencia; los comandos anteriores son portables.

## Flujo UI -> Servicio -> Repositorio (resumen para el equipo)

- Usuario realiza una acción (ej. guarda una transacción) en la UI.
- `TransactionsController` guarda la transacción en la base de datos y dispara `gamificationService.recordEvent(...)` (no bloqueante).
- `GamificationService` calcula puntos (según `transactionType` o `puntosOtorgados`), actualiza `GamificationRepository.upsertProfile(...)`, crea un registro en `gamification_events` y llama a `evaluateAchievements(usuarioId)`.
- `evaluateAchievements` consulta `listAchievements()` y, según reglas (tipo `points` o `streak`), actualiza el/los logros con `updateAchievement(...)` y opcionalmente inserta un evento `achievement_unlocked`.
- Los providers (p.ej. `gamificationDashboardProvider`) se invalidan/recargan cuando las operaciones completan (usar `ref.invalidate(...)` o retornar nuevas futuras para que la UI se refresque).

## Tests widget: checklist mínimo para el PR de la tarde
- [ ] `GamificationScreen` renderiza y muestra encabezado con puntos/level/racha.
- [ ] Muestra al menos una tarjeta de logro con título y estado.
- [ ] Lista de eventos muestra al menos un evento reciente.
- [ ] `TransactionsController` mockeado dispara `gamificationService.recordEvent` cuando se guarda una transacción (unit test).
- [ ] Tests pasan en CI local con `flutter test`.

## Documentación y seguimiento
- Actualiza `docs/gamification.md` (este archivo) con cualquier cambio adicional en reglas, niveles o tipos de evento.
- Si se decide que los logros deben ser por usuario, abrir la issue `v15 user_achievements` (sugerido) y asignarla al sprint correspondiente.

---

Si quieres, además puedo:
- Crear un `test/presentation/gamification/gamification_screen_test.dart` con el placeholder de test y un `FakeGamificationRepository` para que el equipo tenga un template listo.
- Crear la ruta en el router y el botón en `home_screen.dart` en un PR separado si quieres que lo haga ahora?

## Smoke test manual (pasos para validar en dispositivo/emulador)

Objetivo: verificar que la navegación, el servicio de gamificación y la persistencia funcionan juntos: al registrar transacciones reales desde la app se deben actualizar `gamification_profiles`, aparecer eventos en `gamification_events` y desbloquear logros cuando corresponda.

Precondiciones
- Tener la app instalada en un emulador Android o dispositivo físico conectado.
- Conocer el package name de la app (por ejemplo `com.example.mype_finanzas`). Reemplaza `PACKAGE_NAME` en los comandos siguientes.
- Tener `adb` disponible en PATH (incluido con Android SDK).

Pasos UI (rápido)
1. Abrir la app y hacer login con un usuario de prueba (o usar el seed user si aplica).
2. Desde la pantalla principal (`MyHomePage`) tocar el icono de gamificación (trofeo) en la AppBar. Debería abrirse la pantalla `GamificationScreen`.
3. Verificar que el encabezado muestre puntos, nivel y racha (inicialmente 0/1/0 o el valor del seed user).
4. Ir a añadir una transacción: FAB o botón "+" -> crear una transacción tipo `ingreso` con monto pequeño. Guardar.
5. Esperar 1-3 segundos. Volver a `GamificationScreen` y refrescar (pull-to-refresh si hace falta).
6. Verificar que:
   - Los `Puntos` incrementaron según las reglas (p. ej. +5 para `ingreso`).
   - El `Nivel` se actualizó si se superó el umbral (500 puntos por nivel por defecto).
   - La `Racha` se actualiza según fecha del evento.
   - En "Eventos recientes" aparece un nuevo evento `transaction_created` con el monto de puntos apropiado.
   - Si el nuevo puntaje desbloquea algún logro del catálogo, el logro aparece como desbloqueado (`unlocked`) y se genera un evento `achievement_unlocked`.

Pruebas adicionales (ejemplos)
- Crear una transacción tipo `egreso` y verificar que se sumen los puntos correspondientes y que, si corresponde, se actualice presupuesto/alertas.
- Crear transacciones en días consecutivos para validar que la racha (`racha_actual`) incremente. Crear una transacción con fecha anterior >24h para forzar reseteo de racha.

Verificar logs (Windows cmd.exe)
- Abrir una terminal cmd.exe y ejecutar:

```cmd
adb logcat -s "➡️ [MyHomePage]" "🔵 [TransactionsController]" "💾 [TransactionsController]" "⚠️" | findstr /i "gamification Gamification recordEvent achievement_unlocked"
```

- También puedes filtrar por la etiqueta del servicio si implementaste prints específicos (p. ej. `Error evaluando achievements`).

Extraer y consultar la base de datos (emulador/device)
1) Extraer la DB desde el dispositivo (cmd.exe). Reemplaza PACKAGE_NAME por el id real.

```cmd
adb shell "run-as PACKAGE_NAME cat databases/app_database.db" > app_db.db
```

Si `run-as` falla (en algunos dispositivos/emuladores no con configuración de debuggable), puedes usar `adb pull` sobre la ruta absoluta del archivo si tienes permisos o abrir la BD desde el host si usas un emulador con almacenamiento accesible.

2) Abrir `app_db.db` con sqlite3 (si lo tienes instalado en Windows), o con DB Browser for SQLite.

```cmd
sqlite3 app_db.db
sqlite> .tables
sqlite> SELECT * FROM gamification_profiles LIMIT 10;
sqlite> SELECT * FROM gamification_events ORDER BY fecha_evento DESC LIMIT 20;
sqlite> SELECT * FROM gamification_achievements LIMIT 20;
sqlite> .exit
```

Comprobaciones SQL clave
- Profile existe y refleja los puntos recientes:

```sql
SELECT usuario_id, puntos, nivel, racha_actual, ultima_fecha_evento FROM gamification_profiles WHERE usuario_id = <TU_USER_ID>;
```

- Eventos recientes:

```sql
SELECT id, tipo_evento, descripcion, puntos_otorgados, fecha_evento, created_at FROM gamification_events WHERE usuario_id = <TU_USER_ID> ORDER BY fecha_evento DESC LIMIT 20;
```

- Logros desbloqueados:

```sql
SELECT id, nombre, tipo, estado, ultima_actualizacion FROM gamification_achievements WHERE estado = 'unlocked';
```

Qué verificar si algo falla
- Si no aparecen cambios en la UI pero sí en la BD: revisar que los providers se invaliden/recarguen; intenta forzar refresh con pull-to-refresh y revisar logs.
- Si no se insertan eventos en BD: revisar `GamificationRepository.insertEvent` y permisos; revisar logs de error del servicio (ver `adb logcat`).
- Si la navegación a `/gamification` desde el AppBar no vuelve al pulsar 'back': asegúrate de usar la versión con `context.push('/gamification')` (implementado en `lib/presentation/features/home/views/home_screen.dart`), y prueba el botón físico Back en Android o el BackButton en AppBar.

Notas finales
- La migración de BD a versión 14 (v14) incluye las tablas `gamification_profiles`, `gamification_achievements` y `gamification_events`. Si tu dispositivo tiene una DB anterior, la `_onUpgrade` debe crear las tablas y preservar datos existentes según lo documentado.
- Si necesitas, puedo crear un script PowerShell o batch que automatice la extracción de la BD y ejecute las consultas SQLite para acelerar el smoke test.
