import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/di/injection.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart' as auth;
import '../../../../core/state/app_ui_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_bloc.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_event.dart';
import '../../../categories/domain/entities/category.dart' as cat;
import '../../../categories/presentation/bloc/categories_bloc.dart';
import '../../../categories/presentation/bloc/categories_event.dart';
import '../../../categories/presentation/bloc/categories_state.dart';
import '../../domain/entities/item.dart';
import '../../domain/repositories/item_repository.dart';
import '../bloc/items_bloc.dart';
import '../bloc/items_state.dart';

class ItemFormPage extends StatefulWidget {
  const ItemFormPage({super.key, this.item});

  final Item? item; // Null for create, Item for edit

  static String routeName = 'ItemFormPage';
  static String routePath = '/items/form';

  @override
  State<ItemFormPage> createState() => _ItemFormPageState();
}

class _ItemFormPageState extends State<ItemFormPage> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final formKey = GlobalKey<FormState>();

  late TextEditingController nameController;
  late FocusNode nameFocusNode;

  late TextEditingController initialValueController;
  late FocusNode initialValueFocusNode;

  late TextEditingController goalController;
  late FocusNode goalFocusNode;

  late TextEditingController incrementByController;
  late FocusNode incrementByFocusNode;

  late TextEditingController reminderValueController;
  late FocusNode reminderValueFocusNode;

  ReminderType? selectedReminder;
  String? selectedCategoryId;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // Initialize controllers with existing item data or defaults
    nameController = TextEditingController(text: widget.item?.name ?? '');
    nameFocusNode = FocusNode();

    initialValueController = TextEditingController(
      text: widget.item?.count.toString() ?? '0',
    );
    initialValueFocusNode = FocusNode();

    goalController = TextEditingController(
      text: widget.item?.goal?.toString() ?? '',
    );
    goalFocusNode = FocusNode();

    incrementByController = TextEditingController(
      text: widget.item?.incrementBy.toString() ?? '1',
    );
    incrementByFocusNode = FocusNode();

    reminderValueController = TextEditingController(
      text: widget.item?.reminderValue.toString() ?? '0',
    );
    reminderValueFocusNode = FocusNode();

    selectedReminder = widget.item?.reminder ?? ReminderType.none;
    selectedCategoryId = widget.item?.categoryId;
  }

  @override
  void dispose() {
    nameController.dispose();
    nameFocusNode.dispose();
    initialValueController.dispose();
    initialValueFocusNode.dispose();
    goalController.dispose();
    goalFocusNode.dispose();
    incrementByController.dispose();
    incrementByFocusNode.dispose();
    reminderValueController.dispose();
    reminderValueFocusNode.dispose();
    super.dispose();
  }

  bool get isEditMode => widget.item != null;

  @override
  Widget build(BuildContext context) {
    // Theme-aware colors
    final brightness = Theme.of(context).brightness;
    final primaryBackground = AppColors.primaryBackground(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final alternate = AppColors.alternate(brightness);

    final userId = _getUserId();

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => sl<ItemsBloc>(),
        ),
        BlocProvider(
          create: (context) => sl<CategoriesBloc>()
            ..add(WatchCategoriesEvent(userId)),
        ),
      ],
      child: BlocListener<ItemsBloc, ItemsState>(
        listener: (context, state) {
          if (state is ItemsLoading) {
            setState(() => _isLoading = true);
          } else {
            setState(() => _isLoading = false);
          }

          if (state is ItemsError) {
            _showErrorDialog(context, state.message);
          }
          // Note: Pop is handled in _handleSave after sync completes
        },
        child: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Scaffold(
            key: scaffoldKey,
            backgroundColor: primaryBackground,
            resizeToAvoidBottomInset: false,
            appBar: AppBar(
              backgroundColor: primaryBackground,
              automaticallyImplyLeading: false,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: primaryText,
                  size: 30.0,
                ),
                onPressed: () {
                  context.pop();
                },
              ),
              title: Text(
                isEditMode ? 'Edit Item' : 'Create Item',
                style: GoogleFonts.interTight(
                  color: primaryText,
                  fontSize: 20.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              centerTitle: true,
              elevation: 0.0,
            ),
            body: SafeArea(
              top: true,
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldSection(
                          label: 'Item Name',
                          labelColor: primaryText,
                          child: TextFormField(
                            controller: nameController,
                            focusNode: nameFocusNode,
                            autofocus: true,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: _buildInputDecoration(
                              hint: 'Enter item name...',
                              alternate: alternate,
                              secondaryText: secondaryText,
                            ),
                            style: GoogleFonts.inter(
                              color: primaryText,
                              fontSize: 16.0,
                              letterSpacing: 0.0,
                            ),
                            maxLength: 30,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Name is required';
                              }
                              if (value.length > 30) {
                                return 'Name must be 30 characters or less';
                              }
                              return null;
                            },
                          ),
                        ),
                        // Category dropdown
                        BlocBuilder<CategoriesBloc, CategoriesState>(
                          builder: (context, categoriesState) {
                            List<cat.Category> categories = [];
                            if (categoriesState is CategoriesLoaded) {
                              categories = categoriesState.categories;
                            }
                            // Validate selectedCategoryId exists in categories list
                            final validCategoryId = selectedCategoryId != null &&
                                categories.any((c) => c.id == selectedCategoryId)
                                ? selectedCategoryId
                                : null;
                            return _buildFieldSection(
                              label: 'Category (optional)',
                              labelColor: primaryText,
                              child: DropdownButtonFormField<String?>(
                                value: validCategoryId,
                                items: [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text(
                                      'Uncategorized',
                                      style: GoogleFonts.inter(
                                        color: secondaryText,
                                        fontSize: 16.0,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                  ...categories.map((category) => DropdownMenuItem<String?>(
                                    value: category.id,
                                    child: Text(
                                      category.name,
                                      style: GoogleFonts.inter(
                                        color: primaryText,
                                        fontSize: 16.0,
                                      ),
                                    ),
                                  )),
                                ],
                                onChanged: (val) {
                                  setState(() => selectedCategoryId = val);
                                },
                                style: GoogleFonts.inter(
                                  color: primaryText,
                                  fontSize: 16.0,
                                ),
                                dropdownColor: alternate,
                                icon: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: secondaryText,
                                  size: 24.0,
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: alternate,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                    borderSide: BorderSide(color: alternate),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                    borderSide: BorderSide(color: alternate),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                ),
                              ),
                            );
                          },
                        ),
                        // Only show Initial Value field when creating (not editing)
                        if (!isEditMode)
                          _buildFieldSection(
                            label: 'Initial Value',
                            labelColor: primaryText,
                            child: TextFormField(
                              controller: initialValueController,
                              focusNode: initialValueFocusNode,
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: _buildInputDecoration(
                                hint: 'Enter initial count...',
                                alternate: alternate,
                                secondaryText: secondaryText,
                              ),
                              style: GoogleFonts.inter(
                                color: primaryText,
                                fontSize: 16.0,
                                letterSpacing: 0.0,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Initial value is required';
                                }
                                final intValue = int.tryParse(value);
                                if (intValue == null || intValue < 0 || intValue > 999999) {
                                  return 'Must be between 0 and 999999';
                                }
                                return null;
                              },
                            ),
                          ),
                        _buildFieldSection(
                          label: 'Goal (optional)',
                          labelColor: primaryText,
                          child: TextFormField(
                            controller: goalController,
                            focusNode: goalFocusNode,
                            textInputAction: TextInputAction.next,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: _buildInputDecoration(
                              hint: 'Enter target goal...',
                              alternate: alternate,
                              secondaryText: secondaryText,
                            ),
                            style: GoogleFonts.inter(
                              color: primaryText,
                              fontSize: 16.0,
                              letterSpacing: 0.0,
                            ),
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                final intValue = int.tryParse(value);
                                if (intValue == null || intValue < 0 || intValue > 999999) {
                                  return 'Must be between 0 and 999999';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                        _buildFieldSection(
                          label: 'Increment By',
                          labelColor: primaryText,
                          child: TextFormField(
                            controller: incrementByController,
                            focusNode: incrementByFocusNode,
                            textInputAction: TextInputAction.next,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: _buildInputDecoration(
                              hint: 'Enter increment value...',
                              alternate: alternate,
                              secondaryText: secondaryText,
                            ),
                            style: GoogleFonts.inter(
                              color: primaryText,
                              fontSize: 16.0,
                              letterSpacing: 0.0,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Increment value is required';
                              }
                              final intValue = int.tryParse(value);
                              if (intValue == null || intValue < 1 || intValue > 100) {
                                return 'Must be between 1 and 100';
                              }
                              return null;
                            },
                          ),
                        ),
                        _buildFieldSection(
                          label: 'Reminder Type',
                          labelColor: primaryText,
                          child: DropdownButtonFormField<ReminderType>(
                            value: selectedReminder,
                            items: const [
                              DropdownMenuItem(value: ReminderType.none, child: Text('No Reminder')),
                              DropdownMenuItem(value: ReminderType.target, child: Text('Target Count')),
                              DropdownMenuItem(value: ReminderType.interval, child: Text('Every X Increments')),
                            ],
                            onChanged: (val) {
                              setState(() => selectedReminder = val);
                            },
                            style: GoogleFonts.inter(
                              color: primaryText,
                              fontSize: 16.0,
                            ),
                            dropdownColor: alternate,
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: secondaryText,
                              size: 24.0,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: alternate,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                borderSide: BorderSide(color: alternate),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                borderSide: BorderSide(color: alternate),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                            ),
                          ),
                        ),
                        if (selectedReminder != ReminderType.none)
                          _buildFieldSection(
                            label: 'Reminder Value',
                            labelColor: primaryText,
                            child: TextFormField(
                              controller: reminderValueController,
                              focusNode: reminderValueFocusNode,
                              textInputAction: TextInputAction.done,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: _buildInputDecoration(
                                hint: 'Enter reminder value...',
                                alternate: alternate,
                                secondaryText: secondaryText,
                              ),
                              style: GoogleFonts.inter(
                                color: primaryText,
                                fontSize: 16.0,
                                letterSpacing: 0.0,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Reminder value is required';
                                }
                                final intValue = int.tryParse(value);
                                if (intValue == null || intValue < 0 || intValue > 1000) {
                                  return 'Must be between 0 and 1000';
                                }
                                return null;
                              },
                            ),
                          ),
                        SizedBox(height: 32.0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 48.0,
                                child: OutlinedButton(
                                  onPressed: _isLoading ? null : () {
                                    context.pop();
                                  },
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: alternate,
                                    side: BorderSide.none,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                  ),
                                  child: Text(
                                    'Cancel',
                                    style: GoogleFonts.interTight(
                                      color: primaryText,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16.0),
                            Expanded(
                              child: SizedBox(
                                height: 48.0,
                                child: Builder(
                                  builder: (blocContext) => ElevatedButton(
                                  onPressed: _isLoading ? null : () => _handleSave(blocContext),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                  ),
                                  child: Text(
                                    isEditMode ? 'Update' : 'Create',
                                    style: GoogleFonts.interTight(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ].fold<List<Widget>>(
                        [],
                        (prev, element) => prev.isEmpty
                            ? [element]
                            : [...prev, SizedBox(height: 20.0), element],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldSection({
    required String label,
    required Widget child,
    required Color labelColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: labelColor,
            letterSpacing: 0.0,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8.0),
        child,
      ],
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required Color alternate,
    required Color secondaryText,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
        color: secondaryText,
        fontSize: 16.0,
        letterSpacing: 0.0,
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: alternate,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: AppColors.primary,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: AppColors.error,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: AppColors.error,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      filled: true,
      fillColor: alternate,
      contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
    );
  }

  /// Checks if an item with the same name already exists (case-insensitive).
  /// Checks both active and soft-deleted items.
  /// Returns true if duplicate exists, false otherwise.
  Future<bool> _checkDuplicateName(String name) async {
    final userId = _getUserId();
    final itemRepository = sl<ItemRepository>();
    final normalizedName = name.toLowerCase();

    // Fetch active items
    final activeResult = await itemRepository.getItems(userId);
    final activeItems = activeResult.fold(
      (failure) => <Item>[],
      (items) => items,
    );

    // Fetch deleted items
    final deletedResult = await itemRepository.getDeletedItems(userId);
    final deletedItems = deletedResult.fold(
      (failure) => <Item>[],
      (items) => items,
    );

    // Combine all items
    final allItems = [...activeItems, ...deletedItems];

    // Check for duplicate (excluding current item if editing)
    for (final item in allItems) {
      // Skip the item being edited
      if (isEditMode && item.id == widget.item!.id) continue;

      if (item.name.toLowerCase() == normalizedName) {
        return true; // Duplicate found
      }
    }

    return false; // No duplicate
  }

  Future<void> _handleSave(BuildContext blocContext) async {
    debugPrint('🔵 _handleSave called');

    // Prevent double-tap by checking and setting loading state immediately
    if (_isLoading) {
      debugPrint('🔴 Already saving, ignoring duplicate tap');
      return;
    }

    if (!formKey.currentState!.validate()) {
      debugPrint('🔴 Form validation failed');
      return;
    }
    debugPrint('🟢 Form validation passed');

    // Set loading state to prevent further taps
    setState(() => _isLoading = true);

    final name = nameController.text.trim();

    // Check for duplicate item name
    final duplicateExists = await _checkDuplicateName(name);
    if (duplicateExists) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An item with this name already exists'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    final initialValue = int.tryParse(initialValueController.text) ?? 0;
    final goalText = goalController.text.trim();
    final goal = goalText.isEmpty ? null : int.tryParse(goalText);
    final incrementBy = int.parse(incrementByController.text);
    final reminderValue = int.parse(reminderValueController.text);
    final reminder = selectedReminder ?? ReminderType.none;

    if (isEditMode) {
      // Update existing item directly via repository to ensure we wait for completion
      final updatedItem = widget.item!.copyWith(
        name: name,
        incrementBy: incrementBy,
        reminder: reminder,
        reminderValue: reminderValue,
        goal: goal,
        clearGoal: goal == null,
        categoryId: selectedCategoryId,
        clearCategoryId: selectedCategoryId == null,
      );

      debugPrint('🟡 Updating item: id=${updatedItem.id}, name=$name');
      debugPrint('🟡 Original: incrementBy=${widget.item!.incrementBy}, reminder=${widget.item!.reminder}');
      debugPrint('🟡 Form values: incrementBy=$incrementBy, reminder=$reminder');
      debugPrint('🟡 Updated item: incrementBy=${updatedItem.incrementBy}, reminder=${updatedItem.reminder}');

      final itemRepository = sl<ItemRepository>();
      final result = await itemRepository.updateItem(updatedItem);

      result.fold(
        (failure) {
          debugPrint('❌ Failed to update item: ${failure.message}');
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to update item: ${failure.message}')),
            );
          }
        },
        (item) async {
          debugPrint('🟢 Item updated: ${item.id}');

          // Sync with device after update
          await _syncWithDevice();

          if (mounted) context.pop();
        },
      );
    } else {
      // Create new item directly via repository to ensure we wait for completion
      final userId = _getUserId();
      debugPrint('🟡 Creating item: name=$name, initialValue=$initialValue, userId=$userId');

      final itemRepository = sl<ItemRepository>();
      final now = DateTime.now();
      final newItem = Item(
        id: '', // Repository will generate
        name: name,
        count: initialValue,
        todayCount: initialValue,
        initialCount: initialValue,
        incrementBy: incrementBy,
        reminder: reminder,
        reminderValue: reminderValue,
        lastResetTime: null, // null = never reset
        lastUpdated: now,
        userId: userId,
        goal: goal,
        categoryId: selectedCategoryId,
      );

      final result = await itemRepository.createItem(newItem);

      result.fold(
        (failure) {
          debugPrint('❌ Failed to create item: ${failure.message}');
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to create item: ${failure.message}')),
            );
          }
        },
        (createdItem) async {
          debugPrint('🟢 Item created with ID: ${createdItem.id}');

          // Set the new item as active in app
          if (mounted) {
            context.read<AppUiState>().activeItemId = createdItem.id;
          }

          // Sync with device after create (item is guaranteed to exist now)
          await _syncWithDevice(newItemId: createdItem.id);
          debugPrint('🟢 _syncWithDevice completed');

          if (mounted) context.pop();
          debugPrint('🟢 Popped');
        },
      );
    }
  }

  /// Gets the current user ID from AuthBloc
  String _getUserId() {
    final authState = context.read<AuthBloc>().state;
    if (authState is auth.Authenticated) {
      return authState.user.id;
    }
    return '';
  }

  Future<void> _syncWithDevice({String? newItemId}) async {
    try {
      debugPrint('🔄 _syncWithDevice started');
      // Small delay to allow Firestore to propagate the write
      await Future.delayed(const Duration(milliseconds: 300));

      // Fetch all items from repository
      final itemRepository = sl<ItemRepository>();
      final itemsResult = await itemRepository.getItems(_getUserId());

      final items = itemsResult.fold(
        (failure) {
          debugPrint('❌ Failed to fetch items: ${failure.message}');
          return <Item>[];
        },
        (items) => items,
      );

      debugPrint('📦 Fetched ${items.length} items');
      for (final item in items) {
        debugPrint('📦 Item: ${item.name}, incrementBy=${item.incrementBy}, reminder=${item.reminder}');
      }

      if (mounted) {
        // Build category names map
        final categoriesState = context.read<CategoriesBloc>().state;
        final categoryNames = categoriesState is CategoriesLoaded
            ? {for (final c in categoriesState.categories) c.id: c.name}
            : <String, String>{};

        // Send items to device
        debugPrint('📤 Sending ${items.length} items to device');
        context.read<BluetoothBloc>().add(SendItemsToDevice(
          items,
          categoryNames: categoryNames,
        ));

        // Wait for device to process items before sending selected item
        await Future.delayed(const Duration(milliseconds: 500));

        // Send selected item to device (use newItemId if provided, otherwise current active)
        final selectedItemId = newItemId ?? context.read<AppUiState>().activeItemId;
        debugPrint('⭐ Selected item ID: $selectedItemId');
        if (selectedItemId.isNotEmpty && selectedItemId != 'none') {
          debugPrint('📤 Sending selected item: $selectedItemId');
          context.read<BluetoothBloc>().add(SendSelectedItem(selectedItemId));
        }

        // NOTE: Don't request prefs from device here!
        // Requesting prefs causes device to send back its stored counts,
        // which may be stale and overwrite Firestore with old values.
        // Device counts should only be fetched during initial connection sync.
      }
      debugPrint('✅ _syncWithDevice completed');
    } catch (e) {
      debugPrint('❌ Error syncing with device: $e');
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (alertDialogContext) {
        return AlertDialog(
          title: Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(alertDialogContext),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
