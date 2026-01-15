import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '/auth/firebase_auth/auth_util.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/state/app_ui_state.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_bloc.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_event.dart';
import '../../domain/entities/item.dart';
import '../../domain/repositories/item_repository.dart';
import '../bloc/items_bloc.dart';
import '../bloc/items_event.dart';
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
  // FF Colors
  static const Color _primary = Color(0xFF4B39EF);
  static const Color _alternate = Color(0xFFE0E3E7);
  static const Color _primaryBackground = Color(0xFFF1F4F8);
  static const Color _primaryText = Color(0xFF14181B);
  static const Color _secondaryText = Color(0xFF57636C);
  static const Color _error = Color(0xFFFF5963);

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final formKey = GlobalKey<FormState>();

  late TextEditingController nameController;
  late FocusNode nameFocusNode;

  late TextEditingController incrementByController;
  late FocusNode incrementByFocusNode;

  late TextEditingController reminderValueController;
  late FocusNode reminderValueFocusNode;

  ReminderType? selectedReminder;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // Initialize controllers with existing item data or defaults
    nameController = TextEditingController(text: widget.item?.name ?? '');
    nameFocusNode = FocusNode();

    incrementByController = TextEditingController(
      text: widget.item?.incrementBy.toString() ?? '1',
    );
    incrementByFocusNode = FocusNode();

    reminderValueController = TextEditingController(
      text: widget.item?.reminderValue.toString() ?? '0',
    );
    reminderValueFocusNode = FocusNode();

    selectedReminder = widget.item?.reminder ?? ReminderType.none;
  }

  @override
  void dispose() {
    nameController.dispose();
    nameFocusNode.dispose();
    incrementByController.dispose();
    incrementByFocusNode.dispose();
    reminderValueController.dispose();
    reminderValueFocusNode.dispose();
    super.dispose();
  }

  bool get isEditMode => widget.item != null;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => sl<ItemsBloc>(),
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

          // After successful create, LoadItemsEvent is triggered by BLoC
          // We can pop here since the list page will update
          if (state is ItemsLoading && !isEditMode) {
            // After create, go back
            Future.delayed(Duration(milliseconds: 500), () {
              if (mounted) {
                context.pop();
              }
            });
          }
        },
        child: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Scaffold(
            key: scaffoldKey,
            backgroundColor: _primaryBackground,
            resizeToAvoidBottomInset: false,
            appBar: AppBar(
              backgroundColor: _primaryBackground,
              automaticallyImplyLeading: false,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: _primaryText,
                  size: 30.0,
                ),
                onPressed: () {
                  context.pop();
                },
              ),
              title: Text(
                isEditMode ? 'Edit Item' : 'Create Item',
                style: GoogleFonts.interTight(
                  color: _primaryText,
                  fontSize: 20.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              centerTitle: true,
              elevation: 2.0,
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
                          child: TextFormField(
                            controller: nameController,
                            focusNode: nameFocusNode,
                            autofocus: true,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: _buildInputDecoration(
                              hint: 'Enter item name...',
                            ),
                            style: GoogleFonts.inter(
                              color: _primaryText,
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
                        _buildFieldSection(
                          label: 'Increment By',
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
                            ),
                            style: GoogleFonts.inter(
                              color: _primaryText,
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
                          child: DropdownButtonFormField<ReminderType>(
                            value: selectedReminder,
                            items: const [
                              DropdownMenuItem(value: ReminderType.none, child: Text('No Reminder')),
                              DropdownMenuItem(value: ReminderType.target, child: Text('Target Count')),
                              DropdownMenuItem(value: ReminderType.interval, child: Text('Every X Increments')),
                              DropdownMenuItem(value: ReminderType.everyTime, child: Text('Every Time')),
                            ],
                            onChanged: (val) {
                              setState(() => selectedReminder = val);
                            },
                            style: GoogleFonts.inter(
                              color: _primaryText,
                              fontSize: 16.0,
                            ),
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: _secondaryText,
                              size: 24.0,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: _alternate,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                borderSide: BorderSide(color: _alternate),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                borderSide: BorderSide(color: _alternate),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                            ),
                          ),
                        ),
                        _buildFieldSection(
                          label: 'Reminder Value',
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
                            ),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontFamily: 'Inter',
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
                                    backgroundColor: _alternate,
                                    side: BorderSide.none,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                  ),
                                  child: Text(
                                    'Cancel',
                                    style: GoogleFonts.interTight(
                                      color: _primaryText,
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
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleSave,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primary,
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

  Widget _buildFieldSection({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: _primaryText,
            letterSpacing: 0.0,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8.0),
        child,
      ],
    );
  }

  InputDecoration _buildInputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
        color: _secondaryText,
        fontSize: 16.0,
        letterSpacing: 0.0,
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: _alternate,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: _primary,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: _error,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: _error,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      filled: true,
      fillColor: _alternate,
      contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
    );
  }

  Future<void> _handleSave() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    final name = nameController.text.trim();
    final incrementBy = int.parse(incrementByController.text);
    final reminderValue = int.parse(reminderValueController.text);
    final reminder = selectedReminder ?? ReminderType.none;

    if (isEditMode) {
      // Update existing item
      final updatedItem = widget.item!.copyWith(
        name: name,
        incrementBy: incrementBy,
        reminder: reminder,
        reminderValue: reminderValue,
      );
      context.read<ItemsBloc>().add(UpdateItemEvent(updatedItem));

      // Sync with device after update
      await _syncWithDevice();

      if (mounted) context.pop();
    } else {
      // Create new item
      context.read<ItemsBloc>().add(CreateItemEvent(
        name: name,
        incrementBy: incrementBy,
        reminder: reminder,
        reminderValue: reminderValue,
        userId: currentUserUid,
      ));

      // Sync with device after create
      await _syncWithDevice();

      if (mounted) context.pop();
    }
  }

  Future<void> _syncWithDevice() async {
    try {
      // Give Firestore a moment to update
      await Future.delayed(const Duration(milliseconds: 300));

      // Fetch all items from repository
      final itemRepository = sl<ItemRepository>();
      final itemsResult = await itemRepository.getItems(currentUserUid);

      final items = itemsResult.fold(
        (failure) => <Item>[],
        (items) => items,
      );

      if (items.isNotEmpty && mounted) {
        // Send items to device
        context.read<BluetoothBloc>().add(SendItemsToDevice(items));

        // Send selected item to device
        final appUiState = context.read<AppUiState>();
        final activeItemId = appUiState.activeItemId;
        if (activeItemId != 'none') {
          context.read<BluetoothBloc>().add(SendSelectedItem(activeItemId));
        }
      }
    } catch (e) {
      debugPrint('Error syncing with device: $e');
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
