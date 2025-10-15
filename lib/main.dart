import 'package:flutter/material.dart';
import 'core/repos/transaction_repo.dart';
import 'core/models/transaction_model.dart';
import 'features/transactions/add_transaction_screen.dart';
import 'core/db/app_database.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'features/transactions/transaction_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await AppDatabase().database;
  debugPrint('📦 Base de datos inicializada: $db');

  // 👇 carga preferencia de sesión
  final prefs = await SharedPreferences.getInstance();
  final stayLogged = prefs.getBool('stay_logged_in') ?? false;

  runApp(MyApp(stayLoggedIn: stayLogged));
}

class MyApp extends StatelessWidget {
  final bool stayLoggedIn;
  const MyApp({super.key, required this.stayLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MYPE Finanzas',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      // Localización
      locale: const Locale('es', 'PE'),
      supportedLocales: const [
        Locale('es', 'PE'),
        Locale('es'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // 👇 Arranque condicional según preferencia
      home: stayLoggedIn
          ? const MyHomePage(title: 'Registro de transacciones')
          : const LoginScreen(),
    );
  }
}

/// ✅ helper de fecha (dd/MM/yyyy)
String formatDate(DateTime date) {
  return DateFormat('dd/MM/yyyy', 'es_PE').format(date);
}

/// =======================
///      LOGIN SCREEN
/// =======================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _rememberMe = false; // 👈 nueva casilla

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final ctx = context; // 👈 guardar contexto

    await Future.delayed(const Duration(milliseconds: 400));
    if (!ctx.mounted) return;

    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (user == 'admin' && pass == '1234') {
      // Guardar preferencia de sesión
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('stay_logged_in', _rememberMe);

      if (!ctx.mounted) return; // 👈 por seguridad después del await
      Navigator.pushReplacement(
        ctx,
        MaterialPageRoute(
          builder: (_) => const MyHomePage(title: 'Registro de transacciones'),
        ),
      );
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('❌ Usuario o contraseña incorrectos')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, size: 64, color: cs.primary),
                      const SizedBox(height: 12),
                      Text('MYPE Finanzas',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _userCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Usuario',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                        v == null || v.isEmpty ? 'Ingrese su usuario' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                                _obscure ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) =>
                        v == null || v.isEmpty ? 'Ingrese su contraseña' : null,
                      ),
                      const SizedBox(height: 8),

                      // 👇 Casilla "Mantener sesión iniciada"
                      CheckboxListTile(
                        value: _rememberMe,
                        onChanged: (v) =>
                            setState(() => _rememberMe = v ?? false),
                        title: const Text('Mantener sesión iniciada'),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),

                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _loading ? null : _login,
                          child: _loading
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Text('Iniciar sesión'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Demo: admin / 1234',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// =======================
///        HOME
/// =======================
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _repo = TransactionRepo();
  late Future<List<AppTransaction>> _futureTransactions;

  String _tipoFilter = 'todos'; // 'todos' | 'ingreso' | 'egreso'
  String _order = 'fecha_desc'; // 'fecha_desc' | 'fecha_asc' | 'monto_desc' | 'monto_asc'
  DateTimeRange? _range; // rango de fechas opcional

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  void _loadTransactions() {
    setState(() {
      _futureTransactions = _repo.list(
        tipo: _tipoFilter == 'todos' ? null : _tipoFilter,
        from: _range?.start,
        to: _range?.end,
        order: _order,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.inversePrimary,
        title: Text(widget.title),
        actions: [
          // Logout con limpieza de sesión
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Guarda el contexto antes del await
              final ctx = context;

              final prefs = await SharedPreferences.getInstance();
              if (!ctx.mounted) return;

              await prefs.remove('stay_logged_in');
              if (!ctx.mounted) return;

              Navigator.pushAndRemoveUntil(
                ctx,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Controles de filtro/orden ---
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                // Tipo
                Flexible(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(_tipoFilter),
                    initialValue: _tipoFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'todos', child: Text('Todos')),
                      DropdownMenuItem(value: 'ingreso', child: Text('Ingresos')),
                      DropdownMenuItem(value: 'egreso', child: Text('Egresos')),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _tipoFilter = v ?? 'todos';
                        _loadTransactions();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // Orden
                Flexible(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(_order),
                    initialValue: _order,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Orden',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'fecha_desc', child: Text('Más recientes')),
                      DropdownMenuItem(value: 'fecha_asc', child: Text('Más antiguos')),
                      DropdownMenuItem(value: 'monto_desc', child: Text('Monto mayor')),
                      DropdownMenuItem(value: 'monto_asc', child: Text('Monto menor')),
                    ],
                    selectedItemBuilder: (context) {
                      const compact = {
                        'fecha_desc': 'Recientes',
                        'fecha_asc': 'Antiguos',
                        'monto_desc': 'Monto ↑',
                        'monto_asc': 'Monto ↓',
                      };
                      const keys = ['fecha_desc', 'fecha_asc', 'monto_desc', 'monto_asc'];
                      return keys.map((k) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text(compact[k]!),
                        );
                      }).toList();
                    },
                    onChanged: (v) {
                      setState(() {
                        _order = v ?? 'fecha_desc';
                        _loadTransactions();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // Fecha
                IconButton(
                  tooltip: _range == null
                      ? 'Filtrar por fecha'
                      : 'Rango: ${_range!.start.year}-${_range!.start.month.toString().padLeft(2, '0')}-${_range!.start.day.toString().padLeft(2, '0')}'
                      ' a ${_range!.end.year}-${_range!.end.month.toString().padLeft(2, '0')}-${_range!.end.day.toString().padLeft(2, '0')}',
                  icon: const Icon(Icons.date_range),
                  onPressed: () async {
                    final now = DateTime.now();
                    final initial = _range ??
                        DateTimeRange(
                          start: DateTime(now.year, now.month, 1),
                          end: DateTime(now.year, now.month + 1, 0),
                        );
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2010),
                      lastDate: DateTime(2100),
                      initialDateRange: initial,
                      helpText: 'Selecciona rango',
                      locale: const Locale('es', 'PE'),
                    );
                    if (picked != null) {
                      setState(() {
                        _range = picked;
                        _loadTransactions();
                      });
                    }
                  },
                  constraints: const BoxConstraints.tightFor(width: 40, height: 40),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),

                // Limpiar
                IconButton(
                  tooltip: 'Limpiar filtros',
                  icon: const Icon(Icons.filter_alt_off),
                  onPressed: () {
                    setState(() {
                      _tipoFilter = 'todos';
                      _order = 'fecha_desc';
                      _range = null;
                      _loadTransactions();
                    });
                  },
                  constraints: const BoxConstraints.tightFor(width: 40, height: 40),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          // --- Lista de transacciones ---
          Expanded(
            child: FutureBuilder<List<AppTransaction>>(
              future: _futureTransactions,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('❌ Error: ${snapshot.error}'));
                }

                final transactions = snapshot.data ?? [];
                if (transactions.isEmpty) {
                  return const Center(child: Text('No hay transacciones con el filtro actual'));
                }

                return ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final t = transactions[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: Icon(
                          t.tipo == 'ingreso' ? Icons.arrow_upward : Icons.arrow_downward,
                          color: t.tipo == 'ingreso' ? Colors.green : Colors.red,
                        ),
                        title: Text(
                          'S/. ${t.monto.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${t.etiqueta ?? 'Sin etiqueta'}\n${formatDate(t.fecha)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        isThreeLine: true,
                        onTap: () async {
                          final changed = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TransactionDetailScreen(tx: t),
                            ),
                          );
                          if (changed == true) {
                            _loadTransactions();
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final saved = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
          );
          if (saved == true) {
            _loadTransactions();
          }
        },
        tooltip: 'Nueva transacción',
        child: const Icon(Icons.add),
      ),
    );
  }
}
