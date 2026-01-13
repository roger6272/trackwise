import 'package:flutter/material.dart';
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'flutter_flow/flutter_flow_util.dart';

class FFAppState extends ChangeNotifier {
  static FFAppState _instance = FFAppState._internal();

  factory FFAppState() {
    return _instance;
  }

  FFAppState._internal();

  static void reset() {
    _instance = FFAppState._internal();
  }

  Future initializePersistedState() async {
    prefs = await SharedPreferences.getInstance();
    _safeInit(() {
      _isactivated = prefs.getString('ff_isactivated') ?? _isactivated;
    });
  }

  void update(VoidCallback callback) {
    callback();
    notifyListeners();
  }

  late SharedPreferences prefs;

  bool _isManualDisconnect = true;
  bool get isManualDisconnect => _isManualDisconnect;
  set isManualDisconnect(bool value) {
    _isManualDisconnect = value;
  }

  DateTime? _datePicked;
  DateTime? get datePicked => _datePicked;
  set datePicked(DateTime? value) {
    _datePicked = value;
  }

  String _isactivated = '';
  String get isactivated => _isactivated;
  set isactivated(String value) {
    _isactivated = value;
    prefs.setString('ff_isactivated', value);
  }

  bool _showcounter = false;
  bool get showcounter => _showcounter;
  set showcounter(bool value) {
    _showcounter = value;
  }

  BTDeviceStruct _BTDevice =
      BTDeviceStruct.fromSerializableMap(jsonDecode('{}'));
  BTDeviceStruct get BTDevice => _BTDevice;
  set BTDevice(BTDeviceStruct value) {
    _BTDevice = value;
  }

  void updateBTDeviceStruct(Function(BTDeviceStruct) updateFn) {
    updateFn(_BTDevice);
  }

  bool _isBTEnabled = false;
  bool get isBTEnabled => _isBTEnabled;
  set isBTEnabled(bool value) {
    _isBTEnabled = value;
  }

  bool _deviceConnected = false;
  bool get deviceConnected => _deviceConnected;
  set deviceConnected(bool value) {
    _deviceConnected = value;
  }

  bool _toggleRefresh = false;
  bool get toggleRefresh => _toggleRefresh;
  set toggleRefresh(bool value) {
    _toggleRefresh = value;
  }

  bool _isListeningToBLE = false;
  bool get isListeningToBLE => _isListeningToBLE;
  set isListeningToBLE(bool value) {
    _isListeningToBLE = value;
  }

  int _currentLogPage = 0;
  int get currentLogPage => _currentLogPage;
  set currentLogPage(int value) {
    _currentLogPage = value;
  }

  bool _isTodayToggle = false;
  bool get isTodayToggle => _isTodayToggle;
  set isTodayToggle(bool value) {
    _isTodayToggle = value;
  }

  bool _isReconnecting = false;
  bool get isReconnecting => _isReconnecting;
  set isReconnecting(bool value) {
    _isReconnecting = value;
  }

  bool _showAfterResetOnly = false;
  bool get showAfterResetOnly => _showAfterResetOnly;
  set showAfterResetOnly(bool value) {
    _showAfterResetOnly = value;
  }
}

void _safeInit(Function() initializeField) {
  try {
    initializeField();
  } catch (_) {}
}

Future _safeInitAsync(Function() initializeField) async {
  try {
    await initializeField();
  } catch (_) {}
}
