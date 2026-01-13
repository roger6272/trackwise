import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '/auth/firebase_auth/auth_util.dart';
import '../../../../core/di/injection.dart';
import '../../../../flutter_flow/flutter_flow_drop_down.dart';
import '../../../../flutter_flow/flutter_flow_icon_button.dart';
import '../../../../flutter_flow/flutter_flow_theme.dart';
import '../../../../flutter_flow/flutter_flow_widgets.dart';
import '../../../../flutter_flow/form_field_controller.dart';
import '../../domain/entities/item.dart';
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
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final formKey = GlobalKey<FormState>();

  late TextEditingController nameController;
  late FocusNode nameFocusNode;

  late TextEditingController incrementByController;
  late FocusNode incrementByFocusNode;

  late TextEditingController reminderValueController;
  late FocusNode reminderValueFocusNode;

  ReminderType? selectedReminder;
  FormFieldController<ReminderType>? reminderDropdownController;

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
            backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
            resizeToAvoidBottomInset: false,
            appBar: AppBar(
              backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
              automaticallyImplyLeading: false,
              leading: FlutterFlowIconButton(
                borderColor: Colors.transparent,
                borderRadius: 30.0,
                borderWidth: 1.0,
                buttonSize: 60.0,
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: FlutterFlowTheme.of(context).primaryText,
                  size: 30.0,
                ),
                onPressed: () {
                  context.pop();
                },
              ),
              title: Text(
                isEditMode ? 'Edit Item' : 'Create Item',
                style: FlutterFlowTheme.of(context).titleLarge.override(
                  fontFamily: 'Inter Tight',
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
                            style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'Inter',
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
                            style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'Inter',
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
                          child: FlutterFlowDropDown<ReminderType>(
                            controller: reminderDropdownController ??=
                                FormFieldController<ReminderType>(selectedReminder),
                            options: [
                              ReminderType.none,
                              ReminderType.target,
                              ReminderType.interval,
                              ReminderType.everyTime,
                            ],
                            optionLabels: [
                              'No Reminder',
                              'Target Count',
                              'Every X Increments',
                              'Every Time',
                            ],
                            onChanged: (val) {
                              setState(() => selectedReminder = val);
                            },
                            width: double.infinity,
                            height: 56.0,
                            textStyle: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'Inter',
                              fontSize: 16.0,
                              letterSpacing: 0.0,
                            ),
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: FlutterFlowTheme.of(context).secondaryText,
                              size: 24.0,
                            ),
                            fillColor: FlutterFlowTheme.of(context).alternate,
                            elevation: 0,
                            borderColor: FlutterFlowTheme.of(context).alternate,
                            borderWidth: 1.0,
                            borderRadius: 8.0,
                            margin: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
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
                            style: FlutterFlowTheme.of(context).bodyMedium.override(
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
                              child: FFButtonWidget(
                                onPressed: _isLoading ? null : () {
                                  context.pop();
                                },
                                text: 'Cancel',
                                options: FFButtonOptions(
                                  height: 48.0,
                                  color: FlutterFlowTheme.of(context).alternate,
                                  textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                                    fontFamily: 'Inter Tight',
                                    color: FlutterFlowTheme.of(context).primaryText,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                            ),
                            SizedBox(width: 16.0),
                            Expanded(
                              child: FFButtonWidget(
                                onPressed: _isLoading ? null : _handleSave,
                                text: isEditMode ? 'Update' : 'Create',
                                options: FFButtonOptions(
                                  height: 48.0,
                                  color: FlutterFlowTheme.of(context).primary,
                                  textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                                    fontFamily: 'Inter Tight',
                                    color: FlutterFlowTheme.of(context).info,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  borderRadius: BorderRadius.circular(8.0),
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
          style: FlutterFlowTheme.of(context).bodyMedium.override(
            fontFamily: 'Inter',
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
      hintStyle: FlutterFlowTheme.of(context).bodyMedium.override(
        fontFamily: 'Inter',
        color: FlutterFlowTheme.of(context).secondaryText,
        fontSize: 16.0,
        letterSpacing: 0.0,
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: FlutterFlowTheme.of(context).alternate,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: FlutterFlowTheme.of(context).primary,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: FlutterFlowTheme.of(context).error,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: FlutterFlowTheme.of(context).error,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      filled: true,
      fillColor: FlutterFlowTheme.of(context).alternate,
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
      context.pop(); // Go back immediately (optimistic)
    } else {
      // Create new item
      context.read<ItemsBloc>().add(CreateItemEvent(
        name: name,
        incrementBy: incrementBy,
        reminder: reminder,
        reminderValue: reminderValue,
        userId: currentUserUid,
      ));
      // BLoC listener will pop after create
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
