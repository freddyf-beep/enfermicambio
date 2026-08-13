import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/ui/app_theme.dart';
import '../../feed/data/supabase_post_repository.dart';
import '../data/open_food_facts_repository.dart';
import '../data/meal_media_repository.dart';
import '../data/supabase_nutrition_repository.dart';
import '../domain/nutrition_models.dart';
import '../domain/nutrition_service.dart';
import 'barcode_scan_screen.dart';

enum _FoodLookupAction { retry, create }

class RegisterTab extends StatefulWidget {
  const RegisterTab({super.key});

  @override
  State<RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends State<RegisterTab> {
  late final SupabasePostRepository _posts;
  late final SupabaseNutritionRepository _nutrition;
  late final MealMediaRepository _mealMedia;
  late final OpenFoodFactsRepository _foodResolver;
  final _imagePicker = ImagePicker();
  List<FoodEntry> _todayEntries = const [];
  int _dailyTarget = 2200;
  bool _loadingToday = true;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _posts = SupabasePostRepository(client: client);
    _nutrition = SupabaseNutritionRepository(client: client);
    _mealMedia = MealMediaRepository(client: client);
    _foodResolver = OpenFoodFactsRepository(
      fallbackLookup: (barcode) async {
        final response = await client.functions.invoke(
          'food_lookup',
          body: {'barcode': barcode},
        );
        final data = response.data;
        if (data is! Map) throw const FormatException('Respuesta inválida');
        return Map<String, dynamic>.from(data);
      },
    );
    _loadToday();
  }

  Future<void> _loadToday() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final results = await Future.wait<Object>([
        _nutrition.listEntriesForDay(),
        if (userId != null)
          Supabase.instance.client
              .from('profiles')
              .select('daily_calorie_target')
              .eq('id', userId)
              .single()
        else
          Future<Map<String, dynamic>>.value(const {}),
      ]);
      if (!mounted) return;
      final profile = results[1] as Map<String, dynamic>;
      setState(() {
        _todayEntries = results[0] as List<FoodEntry>;
        _dailyTarget =
            (profile['daily_calorie_target'] as num?)?.toInt() ?? 2200;
        _loadingToday = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _loadingToday = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cargar tu diario de comidas: $error'),
        ),
      );
    }
  }

  Future<void> _deleteEntry(FoodEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar comida'),
        content: Text(
          '¿Eliminar ${entry.foodName} de tu diario? Esto no elimina una publicación que ya hayas compartido.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _nutrition.deleteEntry(entry.id);
      await _loadToday();
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $error')));
      }
    }
  }

  Future<void> _editEntry(FoodEntry entry) async {
    final edited = await showDialog<FoodEntry>(
      context: context,
      builder: (_) => _EditFoodEntryDialog(entry: entry),
    );
    if (edited == null) return;
    try {
      await _nutrition.updateEntry(edited);
      await _loadToday();
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo editar: $error')));
      }
    }
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
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      if (!mounted) return;
      final wantsSettings = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Permiso de cámara'),
          content: const Text(
            'Activa la cámara para escanear códigos. También puedes ingresar el código manualmente.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Abrir ajustes'),
            ),
          ],
        ),
      );
      if (wantsSettings == true) {
        await openAppSettings();
      }
      return;
    }
    if (!mounted) return;
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => BarcodeScanScreen(onResult: (_) {})),
    );
    if (barcode == null || barcode.isEmpty) return;
    await _resolveBarcode(barcode);
  }

  Future<void> _resolveBarcode(String barcode) async {
    try {
      final normalized = OpenFoodFactsRepository.normalizeBarcode(barcode);
      if (normalized == null) throw FoodLookupFailure.invalidBarcode;
      final cached = await _nutrition.findByBarcode(normalized);
      if (cached != null) {
        if (mounted) await _showLogMealDialog(cached);
        return;
      }
      final food = await _foodResolver.resolveByBarcode(normalized);
      if (!mounted) return;
      await _showLogMealDialog(food);
    } on FoodLookupFailure catch (failure) {
      if (!mounted) return;
      if (failure == FoodLookupFailure.invalidBarcode) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El código debe contener 8, 12, 13 o 14 números.'),
          ),
        );
        return;
      }

      final normalized = OpenFoodFactsRepository.normalizeBarcode(barcode);
      final action = await showDialog<_FoodLookupAction>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            failure == FoodLookupFailure.notFound
                ? 'Producto no encontrado'
                : 'No pudimos consultar el producto',
          ),
          content: Text(
            '${_foodLookupMessage(failure)}\n\n'
            'Puedes reintentar o crearlo manualmente. Quedará disponible para los cuatro usuarios.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            TextButton.icon(
              onPressed: () =>
                  Navigator.pop(dialogContext, _FoodLookupAction.retry),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _FoodLookupAction.create),
              child: const Text('Crear alimento'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (action == _FoodLookupAction.retry) {
        await _resolveBarcode(normalized ?? barcode);
        return;
      }
      if (action == _FoodLookupAction.create) {
        final created = await _showCustomFoodModal(barcode: normalized);
        if (created != null && mounted) await _showLogMealDialog(created);
      }
    }
  }

  String _foodLookupMessage(FoodLookupFailure failure) => switch (failure) {
    FoodLookupFailure.notFound =>
      'Open Food Facts no tiene registrado el código escaneado.',
    FoodLookupFailure.timeout =>
      'Open Food Facts tardó demasiado en responder.',
    FoodLookupFailure.network =>
      'El servicio de alimentos está temporalmente sin conexión.',
    FoodLookupFailure.malformed =>
      'El servicio devolvió datos incompletos para este producto.',
    FoodLookupFailure.invalidBarcode =>
      'El código escaneado no tiene un formato válido.',
  };

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
      await _loadToday();
      final userId = Supabase.instance.client.auth.currentSession?.user.id;
      if (userId != null && await _offerPublishMeal(saved)) {
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

  /// Returns false intentionally: legacy callers used to publish immediately
  /// after logging. Publishing is now an explicit choice made here.
  Future<bool> _offerPublishMeal(
    FoodEntry entry, {
    String? caption,
    List<String> mediaUrls = const [],
  }) async {
    if (!mounted) return false;
    final publish = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Compartir con el grupo?'),
        content: const Text(
          'La comida ya se guardó en tu diario privado. Solo se verá en el feed si la compartes ahora.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Mantener privada'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Publicar'),
          ),
        ],
      ),
    );
    if (publish != true) return false;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      await _posts.createMealPost(
        authorId: userId,
        foodEntryId: entry.id,
        mediaUrls: mediaUrls,
        caption:
            caption ??
            '🍽️ ${entry.foodName} · ${entry.calories.round()} kcal · ${_mealLabel(entry.mealType)}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comida compartida en el feed.')),
        );
      }
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'La comida se guardó, pero no se pudo publicar: $error',
            ),
          ),
        );
      }
    }
    return false;
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
      maxHeight: 1600,
    );
    if (image == null || !mounted) return;
    final draft = await showDialog<_PhotoMealDraft>(
      context: context,
      builder: (_) => const _PhotoMealDialog(),
    );
    if (draft == null || !mounted) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    FoodEntry saved;
    try {
      saved = await _nutrition.createEntry(
        FoodEntry(
          id: '',
          foodName: draft.name,
          mealType: draft.mealType,
          quantity: 1,
          unit: 'porción',
          calories: draft.calories,
          proteinG: draft.proteinG,
          carbsG: draft.carbsG,
          fatG: draft.fatG,
          loggedAt: DateTime.now(),
        ),
      );
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar la comida: $error')),
        );
      }
      return;
    }

    late final MealMediaUpload upload;
    try {
      upload = await _mealMedia.uploadWithRetry(
        userId: userId,
        filePath: image.path,
        contentType: image.mimeType ?? 'image/jpeg',
      );
      saved = await _nutrition.updateEntry(
        saved.copyWith(photoUrl: upload.reference),
      );
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'La comida se guardó, pero la foto no pudo subir. Inténtalo otra vez desde el diario.',
            ),
            action: SnackBarAction(
              label: 'Reintentar',
              onPressed: () => _retryPhoto(saved, image),
            ),
          ),
        );
      }
      return;
    }

    await _offerPublishMeal(
      saved,
      caption: draft.caption.isEmpty
          ? '🍽️ ${draft.name} · ${draft.calories.round()} kcal'
          : draft.caption,
      mediaUrls: [upload.reference],
    );
    await _loadToday();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comida y foto guardadas en tu diario.')),
      );
    }
  }

  Future<void> _retryPhoto(FoodEntry entry, XFile image) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final upload = await _mealMedia.uploadWithRetry(
        userId: userId,
        filePath: image.path,
        contentType: image.mimeType ?? 'image/jpeg',
      );
      final saved = await _nutrition.updateEntry(
        entry.copyWith(photoUrl: upload.reference),
      );
      await _loadToday();
      await _offerPublishMeal(saved, mediaUrls: [upload.reference]);
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('La foto sigue pendiente: $error')),
        );
      }
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
          _TodayNutritionCard(
            entries: _todayEntries,
            targetCalories: _dailyTarget,
            loading: _loadingToday,
            onDelete: _deleteEntry,
            onEdit: _editEntry,
            onRefresh: _loadToday,
          ),
          const SizedBox(height: 16),
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

class _PhotoMealDraft {
  const _PhotoMealDraft({
    required this.name,
    required this.mealType,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.caption,
  });

  final String name;
  final MealType mealType;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final String caption;
}

class _PhotoMealDialog extends StatefulWidget {
  const _PhotoMealDialog();

  @override
  State<_PhotoMealDialog> createState() => _PhotoMealDialogState();
}

class _PhotoMealDialogState extends State<_PhotoMealDialog> {
  final _name = TextEditingController();
  final _calories = TextEditingController();
  final _protein = TextEditingController(text: '0');
  final _carbs = TextEditingController(text: '0');
  final _fat = TextEditingController(text: '0');
  final _caption = TextEditingController();
  MealType _mealType = MealType.lunch;

  @override
  void dispose() {
    _name.dispose();
    _calories.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    _caption.dispose();
    super.dispose();
  }

  double? _number(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  void _save() {
    final name = _name.text.trim();
    final calories = _number(_calories.text);
    final protein = _number(_protein.text) ?? 0;
    final carbs = _number(_carbs.text) ?? 0;
    final fat = _number(_fat.text) ?? 0;
    if (name.isEmpty ||
        calories == null ||
        calories < 0 ||
        protein < 0 ||
        carbs < 0 ||
        fat < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Agrega el nombre y calorías válidas. Los macros no pueden ser negativos.',
          ),
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      _PhotoMealDraft(
        name: name,
        mealType: _mealType,
        calories: calories,
        proteinG: protein,
        carbsG: carbs,
        fatG: fat,
        caption: _caption.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Registrar comida con foto'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(labelText: '¿Qué comiste? *'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<MealType>(
            initialValue: _mealType,
            decoration: const InputDecoration(labelText: 'Momento'),
            items: const [
              DropdownMenuItem(
                value: MealType.breakfast,
                child: Text('Desayuno'),
              ),
              DropdownMenuItem(value: MealType.lunch, child: Text('Almuerzo')),
              DropdownMenuItem(value: MealType.dinner, child: Text('Cena')),
              DropdownMenuItem(value: MealType.snack, child: Text('Snack')),
              DropdownMenuItem(value: MealType.other, child: Text('Otro')),
            ],
            onChanged: (value) => setState(() => _mealType = value!),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _calories,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Calorías *',
              suffixText: 'kcal',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _protein,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Proteínas (g)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _carbs,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Carbos (g)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _fat,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Grasas (g)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _caption,
            maxLength: 500,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Texto para el feed (opcional)',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _save, child: const Text('Guardar comida')),
    ],
  );
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

class _EditFoodEntryDialog extends StatefulWidget {
  const _EditFoodEntryDialog({required this.entry});
  final FoodEntry entry;

  @override
  State<_EditFoodEntryDialog> createState() => _EditFoodEntryDialogState();
}

class _EditFoodEntryDialogState extends State<_EditFoodEntryDialog> {
  late final TextEditingController _name;
  late final TextEditingController _quantity;
  late final TextEditingController _calories;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fat;
  late MealType _mealType;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _name = TextEditingController(text: entry.foodName);
    _quantity = TextEditingController(text: entry.quantity.toString());
    _calories = TextEditingController(text: entry.calories.toString());
    _protein = TextEditingController(text: entry.proteinG.toString());
    _carbs = TextEditingController(text: entry.carbsG.toString());
    _fat = TextEditingController(text: entry.fatG.toString());
    _mealType = entry.mealType;
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _calories.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    super.dispose();
  }

  double? _number(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  void _save() {
    final name = _name.text.trim();
    final quantity = _number(_quantity.text);
    final calories = _number(_calories.text);
    final protein = _number(_protein.text);
    final carbs = _number(_carbs.text);
    final fat = _number(_fat.text);
    if (name.isEmpty ||
        quantity == null ||
        quantity <= 0 ||
        calories == null ||
        calories < 0 ||
        protein == null ||
        protein < 0 ||
        carbs == null ||
        carbs < 0 ||
        fat == null ||
        fat < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revisa nombre, cantidad, calorías y macros.'),
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      widget.entry.copyWith(
        foodName: name,
        quantity: quantity,
        calories: calories,
        proteinG: protein,
        carbsG: carbs,
        fatG: fat,
        mealType: _mealType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Editar comida'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          DropdownButtonFormField<MealType>(
            initialValue: _mealType,
            decoration: const InputDecoration(labelText: 'Momento'),
            items: const [
              DropdownMenuItem(
                value: MealType.breakfast,
                child: Text('Desayuno'),
              ),
              DropdownMenuItem(value: MealType.lunch, child: Text('Almuerzo')),
              DropdownMenuItem(value: MealType.dinner, child: Text('Cena')),
              DropdownMenuItem(value: MealType.snack, child: Text('Snack')),
              DropdownMenuItem(value: MealType.other, child: Text('Otro')),
            ],
            onChanged: (value) => setState(() => _mealType = value!),
          ),
          TextField(
            controller: _quantity,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Cantidad (${widget.entry.unit})',
            ),
          ),
          TextField(
            controller: _calories,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Calorías'),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _protein,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'P g'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _carbs,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'C g'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _fat,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'G g'),
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
      FilledButton(onPressed: _save, child: const Text('Guardar')),
    ],
  );
}

class _TodayNutritionCard extends StatelessWidget {
  const _TodayNutritionCard({
    required this.entries,
    required this.targetCalories,
    required this.loading,
    required this.onDelete,
    required this.onEdit,
    required this.onRefresh,
  });

  final List<FoodEntry> entries;
  final int targetCalories;
  final bool loading;
  final ValueChanged<FoodEntry> onDelete;
  final ValueChanged<FoodEntry> onEdit;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final totals = const NutritionService().totalsForDay(
      entries: entries,
      targetCalories: targetCalories.toDouble(),
    );
    final remaining = totals.remainingCalories;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.restaurant_outlined,
                  color: AppColors.macroCarbs,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Mi alimentación de hoy',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                IconButton(
                  onPressed: loading ? null : onRefresh,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Actualizar diario',
                ),
              ],
            ),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              const SizedBox(height: 8),
              Text(
                '${totals.calories.round()} kcal consumidas de $targetCalories kcal',
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: targetCalories <= 0
                    ? 0
                    : (totals.calories / targetCalories).clamp(0.0, 1.0),
                color: remaining >= 0
                    ? AppColors.fitnessGreen
                    : AppColors.streakOrange,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 8),
              Text(
                remaining >= 0
                    ? 'Presupuesto restante: ${remaining.round()} kcal'
                    : 'Llevas ${remaining.abs().round()} kcal sobre tu presupuesto',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: remaining >= 0
                      ? AppColors.fitnessGreen
                      : AppColors.streakOrange,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'P ${totals.proteinG.round()} g · C ${totals.carbsG.round()} g · G ${totals.fatG.round()} g',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              if (entries.isEmpty)
                const Text(
                  'Aún no registras comidas hoy. Escanea, busca o crea una comida.',
                )
              else
                for (final entry in entries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      entry.photoUrl == null
                          ? Icons.restaurant
                          : Icons.photo_camera,
                      color: AppColors.macroCarbs,
                    ),
                    title: Text(
                      entry.foodName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${_mealTypeText(entry.mealType)} · ${entry.quantity.toStringAsFixed(entry.quantity % 1 == 0 ? 0 : 1)} ${entry.unit}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${entry.calories.round()} kcal',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Editar',
                          onPressed: () => onEdit(entry),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Eliminar',
                          onPressed: () => onDelete(entry),
                        ),
                      ],
                    ),
                  ),
              const SizedBox(height: 6),
              const Text(
                'Estimación orientativa; no equivale a un diagnóstico ni a déficit metabólico real.',
                style: TextStyle(fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _mealTypeText(MealType value) => switch (value) {
    MealType.breakfast => 'Desayuno',
    MealType.lunch => 'Almuerzo',
    MealType.dinner => 'Cena',
    MealType.snack => 'Snack',
    MealType.other => 'Otro',
  };
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
