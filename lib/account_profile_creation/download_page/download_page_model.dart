import '/flutter_flow/flutter_flow_calendar.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import 'download_page_widget.dart' show DownloadPageWidget;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class DownloadPageModel extends FlutterFlowModel<DownloadPageWidget> {
  ///  Local state fields for this page.

  bool fromtoggle = false;

  bool totoggle = false;

  DateTime? exportfromdate;

  DateTime? exporttodate;

  ///  State fields for stateful widgets in this page.

  final formKey = GlobalKey<FormState>();
  // State field(s) for FromCalendar widget.
  DateTimeRange? fromCalendarSelectedDay;
  // State field(s) for ToCalendar widget.
  DateTimeRange? toCalendarSelectedDay;
  // State field(s) for DropDown-aggregate widget.
  String? dropDownAggregateValue;
  FormFieldController<String>? dropDownAggregateValueController;
  // State field(s) for TextField-email widget.
  FocusNode? textFieldEmailFocusNode;
  TextEditingController? textFieldEmailTextController;
  String? Function(BuildContext, String?)?
      textFieldEmailTextControllerValidator;

  @override
  void initState(BuildContext context) {
    fromCalendarSelectedDay = DateTimeRange(
      start: DateTime.now().startOfDay,
      end: DateTime.now().endOfDay,
    );
    toCalendarSelectedDay = DateTimeRange(
      start: DateTime.now().startOfDay,
      end: DateTime.now().endOfDay,
    );
  }

  @override
  void dispose() {
    textFieldEmailFocusNode?.dispose();
    textFieldEmailTextController?.dispose();
  }
}
