import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'item_update_page_widget.dart' show ItemUpdatePageWidget;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ItemUpdatePageModel extends FlutterFlowModel<ItemUpdatePageWidget> {
  ///  State fields for stateful widgets in this page.

  final formKey = GlobalKey<FormState>();
  // State field(s) for TextField-ItemName widget.
  FocusNode? textFieldItemNameFocusNode;
  TextEditingController? textFieldItemNameTextController;
  String? Function(BuildContext, String?)?
      textFieldItemNameTextControllerValidator;
  // State field(s) for TextField-IncrementBy widget.
  FocusNode? textFieldIncrementByFocusNode;
  TextEditingController? textFieldIncrementByTextController;
  String? Function(BuildContext, String?)?
      textFieldIncrementByTextControllerValidator;
  // State field(s) for Dropdown-Reminder widget.
  String? dropdownReminderValue;
  FormFieldController<String>? dropdownReminderValueController;
  // State field(s) for TextField-ReminderTarget widget.
  FocusNode? textFieldReminderTargetFocusNode;
  TextEditingController? textFieldReminderTargetTextController;
  String? Function(BuildContext, String?)?
      textFieldReminderTargetTextControllerValidator;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    textFieldItemNameFocusNode?.dispose();
    textFieldItemNameTextController?.dispose();

    textFieldIncrementByFocusNode?.dispose();
    textFieldIncrementByTextController?.dispose();

    textFieldReminderTargetFocusNode?.dispose();
    textFieldReminderTargetTextController?.dispose();
  }
}
