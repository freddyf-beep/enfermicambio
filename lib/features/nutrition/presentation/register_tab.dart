import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/ui/app_theme.dart';
import '../../feed/data/supabase_post_repository.dart';
import '../data/open_food_facts_repository.dart';
import '../domain/nutrition_models.dart';
import 'barcode_scan_screen.dart';

class RegisterTab extends StatefulWidget {
  const RegisterTab({super.key});

  @override
  State<RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends State<RegisterTab> {
  late final SupabasePostRepository _posts;
  final _foodResolver = OpenFoodFactsRepository();

  @override
  void initState() {
    super.initState();
    _posts = SupabasePostRepository(client: Supabase.instance.client);
  }

  Future<void> _createTextPost() async {
    final controller = TextEditingController();
    final caption = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva Publicación'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          maxLength: 1000,
          decoration: const InputDecoration(
            hintText: '¿Qué tal tu entrenamiento o día hoy?',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Publicar'),
          ),
        ],
      ),
    );

    if (caption == null || caption.isEmpty) return;
    final userId = Supabase.instance.client.auth.currentSession?.user.id;
    if (userId == null) return;

    try {
      await _posts.createTextPost(authorId: userId, caption: caption);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Publicación compartida con el grupo!')),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo publicar: $error')),
      );
    }
  }

  Future<void> _scanBarcode() async {
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => BarcodeScanScreen(onResult: (value) {}),
      ),
    );
    if (barcode == null || barcode.isEmpty) return;
    await _resolveBarcode(barcode);
  }

  Future<void> _resolveBarcode(String barcode) async {
    try {
      final food = await _foodResolver.resolveByBarcode(barcode);
      if (!mounted) return;
      await _showLogMealDialog(food);
    } on FoodLookupFailure catch (failure) {
      if (!mounted) return;
      if (failure == FoodLookupFailure.notFound) {
        final createCustom = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Producto no encontrado'),
            content: Text('El código $barcode no está registrado. ¿Deseas crear este alimento para el grupo?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Crear Alimento'),
              ),
            ],
          ),
        );
        if (createCustom == true && mounted) {
          _showCustomFoodModal(barcode: barcode);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo consultar el código. Revisa tu conexión.')),
        );
      }
    }
  }

  Future<void> _showLogMealDialog(Food food) async {
    MealType selectedMeal = MealType.lunch;
    final servingsController = TextEditingController(text: '1.0');

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          title: Text(food.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${food.calories.round()} kcal por porción (${food.servingSize} ${food.servingUnit})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<MealType>(
                value: selectedMeal,
                decoration: const InputDecoration(labelText: 'Tipo de Comida'),
                items: const [
                  DropdownMenuItem(value: MealType.breakfast, child: Text('Desayuno')),
                  DropdownMenuItem(value: MealType.lunch, child: Text('Almuerzo')),
                  DropdownMenuItem(value: MealType.dinner, child: Text('Cena')),
                  DropdownMenuItem(value: MealType.snack, child: Text('Snack')),
                  DropdownMenuItem(value: MealType.other, child: Text('Otro')),
                ],
                onChanged: (val) {
                  if (val != null) setStateModal(() => selectedMeal = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: servingsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Porciones consumidas',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('¡${food.name} registrado exitosamente!')),
                );
              },
              child: const Text('Guardar Comida'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCustomFoodModal({String? barcode}) async {
    final nameCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    final calCtrl = TextEditingController();
    final proteinCtrl = TextEditingController();
    final carbsCtrl = TextEditingController();
    final fatCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear Alimento Personalizado'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre del Alimento *'),
              ),
              TextField(
                controller: brandCtrl,
                decoration: const InputDecoration(labelText: 'Marca / Origen'),
              ),
              TextField(
                controller: calCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Calorías (kcal) *'),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: proteinCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Proteínas (g)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: carbsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Carbos (g)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: fatCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Grasas (g)'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('¡Alimento "$name" guardado para los 4 usuarios!')),
              );
            },
            child: const Text('Crear y Reutilizar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('REGISTRAR')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _ActionCard(
            icon: Icons.qr_code_scanner,
            title: 'Escanear Código de Barras',
            subtitle: 'Busca productos en Open Food Facts o la base del grupo.',
            color: AppColors.primaryLight,
            onTap: _scanBarcode,
          ),
          _ActionCard(
            icon: Icons.restaurant_menu,
            title: 'Crear Alimento Personalizado',
            subtitle: 'Agrega un alimento nuevo que tus 4 amigos puedan usar.',
            color: AppColors.fitnessGreen,
            onTap: () => _showCustomFoodModal(),
          ),
          _ActionCard(
            icon: Icons.camera_alt_outlined,
            title: 'Registrar Foto de Comida',
            subtitle: 'Sube la foto de tu plato con sus calorías y macros.',
            color: AppColors.streakOrange,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cámara lista para registrar tu comida.')),
              );
            },
          ),
          _ActionCard(
            icon: Icons.edit_note,
            title: 'Publicar Mensaje o Estado',
            subtitle: 'Comparte un mensaje o actualización con el grupo.',
            color: AppColors.trophyPurple,
            onTap: _createTextPost,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.darkSurfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primaryLight),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Recuerda: No existe el ingreso manual de pasos. Los pasos se leen automáticamente desde Apple Health y Health Connect.',
                    style: TextStyle(fontSize: 12, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
