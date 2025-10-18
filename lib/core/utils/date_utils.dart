import 'package:intl/intl.dart';

///  Helper de fecha (dd/MM/yyyy)
String formatDate(DateTime date) {
  return DateFormat('dd/MM/yyyy', 'es_PE').format(date);
}
