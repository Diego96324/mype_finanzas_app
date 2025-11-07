import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/category_providers.dart';

class BusinessTemplateSelector extends ConsumerWidget {
  const BusinessTemplateSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(businessTemplatesProvider);

    return AlertDialog(
      title: const Text('Seleccionar Plantilla de Negocio'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: templates.length,
          itemBuilder: (context, index) {
            final template = templates[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _parseColor(template.color).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getIconData(template.icono),
                    color: _parseColor(template.color),
                  ),
                ),
                title: Text(
                  template.nombre,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(template.descripcion),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context, template.id);
                },
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }

  Color _parseColor(String colorHex) {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }

  IconData _getIconData(String iconName) {
    final iconMap = <String, IconData>{
      'store': Icons.store,
      'restaurant': Icons.restaurant,
      'work': Icons.work,
      'local_shipping': Icons.local_shipping,
      'construction': Icons.construction,
      'face': Icons.face,
      'category': Icons.category,
    };
    return iconMap[iconName] ?? Icons.category;
  }
}

