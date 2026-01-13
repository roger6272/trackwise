import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_calendar.dart';
import '/flutter_flow/flutter_flow_choice_chips.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:math';
import 'dart:ui';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/custom_functions.dart' as functions;
import 'detail_page_widget.dart' show DetailPageWidget;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class DetailPageModel extends FlutterFlowModel<DetailPageWidget> {
  ///  Local state fields for this page.

  bool showcalendar = true;

  DateTime? pickedday;

  ///  State fields for stateful widgets in this page.

  // State field(s) for ChoiceChips-Agg widget.
  FormFieldController<List<String>>? choiceChipsAggValueController;
  String? get choiceChipsAggValue =>
      choiceChipsAggValueController?.value?.firstOrNull;
  set choiceChipsAggValue(String? val) =>
      choiceChipsAggValueController?.value = val != null ? [val] : [];
  // State field(s) for ChoiceChips-Reset widget.
  FormFieldController<List<String>>? choiceChipsResetValueController;
  String? get choiceChipsResetValue =>
      choiceChipsResetValueController?.value?.firstOrNull;
  set choiceChipsResetValue(String? val) =>
      choiceChipsResetValueController?.value = val != null ? [val] : [];
  // State field(s) for Calendar widget.
  DateTimeRange? calendarSelectedDay;
  // State field(s) for Switch widget.
  bool? switchValue;

  @override
  void initState(BuildContext context) {
    calendarSelectedDay = DateTimeRange(
      start: DateTime.now().startOfDay,
      end: DateTime.now().endOfDay,
    );
  }

  @override
  void dispose() {}
}
