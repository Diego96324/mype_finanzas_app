import 'package:flutter/material.dart';
import 'core/repos/transaction_repo.dart';
import 'core/models/transaction_model.dart';
import 'features/transactions/add_transaction_screen.dart';
import 'core/db/app_database.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'features/transactions/transaction_detail_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await AppDatabase().database;
  debugPrint('📦 Base de datos inicializada: $db');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
      home: const MyHomePage(title: 'Registro de transacciones'),
    );
  }
}

// ✅ helper de fecha (dd/MM/yyyy)
String formatDate(DateTime date) {
  return DateFormat('dd/MM/yyyy', 'es_PE').format(date);
}

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
  DateTimeRange? _range;        // rango de fechas opcional

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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
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
                    key: ValueKey(_tipoFilter),   // 👈 fuerza rebuild al cambiar
                    initialValue: _tipoFilter,    // 👈 API recomendada (3.33+)
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'todos',  child: Text('Todos')),
                      DropdownMenuItem(value: 'ingreso', child: Text('Ingresos')),
                      DropdownMenuItem(value: 'egreso',  child: Text('Egresos')),
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
                    key: ValueKey(_order),       // 👈 fuerza rebuild al cambiar
                    initialValue: _order,        // 👈 API recomendada (3.33+)
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Orden',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'fecha_desc', child: Text('Más recientes')),
                      DropdownMenuItem(value: 'fecha_asc',  child: Text('Más antiguos')),
                      DropdownMenuItem(value: 'monto_desc', child: Text('Monto mayor')),
                      DropdownMenuItem(value: 'monto_asc',  child: Text('Monto menor')),
                    ],
                    // Texto compacto cuando está seleccionado
                    selectedItemBuilder: (context) {
                      const compact = {
                        'fecha_desc': 'Recientes',
                        'fecha_asc':  'Antiguos',
                        'monto_desc': 'Monto ↑',
                        'monto_asc':  'Monto ↓',
                      };
                      const keys = ['fecha_desc','fecha_asc','monto_desc','monto_asc'];
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
                      : 'Rango: ${_range!.start.year}-${_range!.start.month.toString().padLeft(2,'0')}-${_range!.start.day.toString().padLeft(2,'0')}'
                      ' a ${_range!.end.year}-${_range!.end.month.toString().padLeft(2,'0')}-${_range!.end.day.toString().padLeft(2,'0')}',
                  icon: const Icon(Icons.date_range),
                  onPressed: () async {
                    final now = DateTime.now();
                    final initial = _range ?? DateTimeRange(
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
