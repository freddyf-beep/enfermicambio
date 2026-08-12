import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/ui/app_theme.dart';
import '../../feed/data/supabase_post_repository.dart';
import '../data/open_food_facts_repository.dart';
import '../data/supabase_nutrition_repository.dart';
import '../domain/nutrition_models.dart';
import '../domain/nutrition_service.dart';
import 'barcode_scan_screen.dart';

class RegisterTab extends StatefulWidget {
  const RegisterTab({super.key});

  @override
  State<RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends State<RegisterTab> {
  late final SupabasePostRepository _posts;
  late final SupabaseNutritionRepository _nutrition;
  final _foodResolver = OpenFoodFactsRepository();
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _posts = SupabasePostRepository(client: client);
    _nutrition = SupabaseNutritionRepository(client: client);
  }

  Future<void> _createTextPost() async {
    final controller = TextEditingController();
    final caption = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nueva publicación'),
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
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Publicar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (caption == null || caption.isEmpty || !mounted) return;

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo publicar: $error')));
    }
  }

  Future<void> _scanBarcode() async {
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => BarcodeScanScreen(onResult: (_) {})),
    );
    if (barcode == null || barcode.isEmpty) return;
    await _resolveBarcode(barcode);
  }

  Future<void> _resolveBarcode(String barcode) async {
    try {
      final cached = await _nutrition.findByBarcode(barcode);
      if (cached != null) {
        if (mounted) await _showLogMealDialog(cached);
        return;
      }
      final food = await _foodResolver.resolveByBarcode(barcode);
      if (!mounted) return;
      await _showLogMealDialog(food);
    } on FoodLookupFailure catch (failure) {
      if (!mounted) return;
      if (failure == FoodLookupFailure.notFound) {
        final createCustom = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Producto no encontrado'),
            content: Text(
              'El código $barcode no está registrado. ¿Deseas crear este alimento para el grupo?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Crear alimento'),
              ),
            ],
          ),
        );
        if (createCustom == true && mounted) {
          final created = await _showCustomFoodModal(barcode: barcode);
          if (created != null && mounted) await _showLogMealDialog(created);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo consultar el código. Revisa tu conexión.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _showLogMealDialog(Food food) async {
    MealType selectedMeal = MealType.lunch;
    final servingsController = TextEditingController(text: '1.0');
    final selection = await showDialog<_MealSelection>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
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
                initialValue: selectedMeal,
                decoration: const InputDecoration(labelText: 'Tipo de comida'),
                items: const [
                  DropdownMenuItem(
                    value: MealType.breakfast,
                    child: Text('Desayuno'),
                  ),
                  DropdownMenuItem(
                    value: MealType.lunch,
                    child: Text('Almuerzo'),
                  ),
                  DropdownMenuItem(value: MealType.dinner, child: Text('Cena')),
                  DropdownMenuItem(value: MealType.snack, child: Text('Snack')),
                  DropdownMenuItem(value: MealType.other, child: Text('Otro')),
                ],
                onChanged: (value) {
                  if (value != null) setStateModal(() => selectedMeal = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: servingsController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Porciones consumidas',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final servings = double.tryParse(
                  servingsController.text.trim().replaceAll(',', '.'),
                );
                if (servings == null || servings <= 0) return;
                Navigator.pop(
                  dialogContext,
                  _MealSelection(mealType: selectedMeal, servings: servings),
                );
              },
              child: const Text('Guardar comida'),
            ),
          ],
        ),
      ),
    );
    servingsController.dispose();
    if (selection == null || !mounted) return;

    try {
      final persistedFood = food.id.isEmpty
          ? await _nutrition.saveFood(food)
          : food;
      final entry = const NutritionService().entryFromServings(
        food: persistedFood,
        servings: selection.servings,
        mealType: selection.mealType,
        loggedAt: DateTime.now(),
      );
      final saved = await _nutrition.createEntry(entry);
      final userId = Supabase.instance.client.auth.currentSession?.user.id;
      if (userId != null) {
        await _posts.createMealPost(
          authorId: userId,
          foodEntryId: saved.id,
          caption:
              '🍽️ ${food.name} · ${saved.calories.round()} kcal · '
              '${_mealLabel(selection.mealType)}',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡${food.name} registrado y publicado en el feed!'),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la comida: $error')),
      );
    }
  }

  Future<Food?> _showCustomFoodModal({String? barcode}) async {
    final nameCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    final servingCtrl = TextEditingController(text: '100');
    final calCtrl = TextEditingController();
    final proteinCtrl = TextEditingController();
    final carbsCtrl = TextEditingController();
    final fatCtrl = TextEditingController();

    final food = await showDialog<Food>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Crear alimento personalizado'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del alimento *',
                ),
              ),
              TextField(
                controller: brandCtrl,
                decoration: const InputDecoration(labelText: 'Marca / origen'),
              ),
              TextField(
                controller: servingCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Tamaño de porción base (g o ml)',
                ),
              ),
              TextField(
                controller: calCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Calorías (kcal) *',
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: proteinCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Proteínas (g)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: carbsCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Carbos (g)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: fatCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Grasas (g)',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final servingSize = _parseNumber(servingCtrl.text);
              final calories = _parseNumber(calCtrl.text);
              if (name.isEmpty ||
                  servingSize == null ||
                  servingSize <= 0 ||
                  calories == null ||
                  calories < 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Completa nombre, porción y calorías.'),
                  ),
                );
                return;
              }
              try {
                final saved = await _nutrition.saveFood(
                  Food(
                    id: '',
                    name: name,
                    barcode: barcode,
                    brand: brandCtrl.text.trim().isEmpty
                        ? null
                        : brandCtrl.text.trim(),
                    servingSize: servingSize,
                    servingUnit: 'g',
                    calories: calories,
                    proteinG: _parseNumber(proteinCtrl.text) ?? 0,
                    carbsG: _parseNumber(carbsCtrl.text) ?? 0,
                    fatG: _parseNumber(fatCtrl.text) ?? 0,
                    source: 'custom',
                  ),
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext, saved);
              } on Exception catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text('No se pudo guardar el alimento: $error'),
                    ),
                  );
                }
              }
            },
            child: const Text('Crear y reutilizar'),
          ),
        ],
      ),
    );
    for (final controller in [
      nameCtrl,
      brandCtrl,
      servingCtrl,
      calCtrl,
      proteinCtrl,
      carbsCtrl,
      fatCtrl,
    ]) {
      controller.dispose();
    }
    return food;
  }

  Future<void> _searchSavedFood() async {
    final selected = await showDialog<Food>(
      context: context,
      builder: (_) => _FoodSearchDialog(repository: _nutrition),
    );
    if (selected != null && mounted) await _showLogMealDialog(selected);
  }

  Future<void> _createMealPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (image == null || !mounted) return;

    final captionController = TextEditingController();
    final caption = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Compartir comida'),
        content: TextField(
          controller: captionController,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(
            hintText: '¿Qué comiste? Puedes añadir calorías o macros.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, captionController.text.trim()),
            child: const Text('Publicar'),
          ),
        ],
      ),
    );
    captionController.dispose();
    if (caption == null || !mounted) return;

    final userId = Supabase.instance.client.auth.currentSession?.user.id;
    if (userId == null) return;
    try {
      await _posts.uploadPhotoPost(
        authorId: userId,
        caption: caption.isEmpty ? '🍽️ Comida registrada' : caption,
        filePath: image.path,
        contentType: image.mimeType ?? 'image/jpeg',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto publicada en el feed.')),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo publicar la foto: $error')),
      );
    }
  }

  double? _parseNumber(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  String _mealLabel(MealType mealType) => switch (mealType) {
    MealType.breakfast => 'desayuno',
    MealType.lunch => 'almuerzo',
    MealType.dinner => 'cena',
    MealType.snack => 'snack',
    MealType.other => 'otra comida',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('REGISTRAR')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _ActionCard(
            icon: Icons.qr_code_scanner,
            title: 'Escanear código de barras',
            subtitle: 'Busca productos en Open Food Facts o la base del grupo.',
            color: AppColors.primaryLight,
            onTap: _scanBarcode,
          ),
          _ActionCard(
            icon: Icons.search,
            title: 'Buscar alimento guardado',
            subtitle:
                'Registra alimentos personalizados o ya usados por el grupo.',
            color: AppColors.macroCarbs,
            onTap: _searchSavedFood,
          ),
          _ActionCard(
            icon: Icons.restaurant_menu,
            title: 'Crear alimento personalizado',
            subtitle:
                'Agrega un alimento nuevo que los 4 amigos puedan reutilizar.',
            color: AppColors.fitnessGreen,
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              final food = await _showCustomFoodModal();
              if (food != null && mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      '¡${food.name} quedó guardado para el grupo!',
                    ),
                  ),
                );
              }
            },
          ),
          _ActionCard(
            icon: Icons.camera_alt_outlined,
            title: 'Foto de comida + feed',
            subtitle:
                'Toma o elige una foto y publícala junto con una descripción.',
            color: AppColors.streakOrange,
            onTap: _createMealPhoto,
          ),
          _ActionCard(
            icon: Icons.edit_note,
            title: 'Publicar mensaje o estado',
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
                    'Los pasos no se ingresan manualmente: se leen desde Apple Health, Health Auto Export o Health Connect.',
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

class _MealSelection {
  const _MealSelection({required this.mealType, required this.servings});

  final MealType mealType;
  final double servings;
}

class _FoodSearchDialog extends StatefulWidget {
  const _FoodSearchDialog({required this.repository});

  final SupabaseNutritionRepository repository;

  @override
  State<_FoodSearchDialog> createState() => _FoodSearchDialogState();
}

class _FoodSearchDialogState extends State<_FoodSearchDialog> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Food> _foods = const [];
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      setState(() => _loading = true);
      try {
        final foods = await widget.repository.searchFoods(value);
        if (mounted) setState(() => _foods = foods);
      } on Exception {
        if (mounted) setState(() => _foods = const []);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Buscar alimento'),
      content: SizedBox(
        width: 420,
        height: 340,
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _scheduleSearch,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Nombre del alimento',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_foods.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('Escribe para buscar alimentos guardados.'),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _foods.length,
                  itemBuilder: (context, index) {
                    final food = _foods[index];
                    return ListTile(
                      title: Text(food.name),
                      subtitle: Text(
                        '${food.calories.round()} kcal · ${food.source}',
                      ),
                      onTap: () => Navigator.pop(context, food),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
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
                  color: color.withValues(alpha: 0.15),
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
