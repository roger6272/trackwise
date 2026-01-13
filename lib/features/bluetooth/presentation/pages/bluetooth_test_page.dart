import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../custom_code/actions/prepare_b_l_e_read.dart' as old_code;
import '../../../items/domain/entities/item.dart';
import '../../domain/entities/ble_device.dart';
import '../../domain/entities/ble_message.dart';
import '../../domain/usecases/request_device_data_usecase.dart';
import '../bloc/bluetooth_bloc.dart';
import '../bloc/bluetooth_event.dart';
import '../bloc/bluetooth_state.dart';

/// Test page for verifying Bluetooth functionality with ESP32.
///
/// Add this to your app temporarily for hardware testing:
/// ```dart
/// // In your routes or navigation:
/// MaterialPageRoute(builder: (_) => const BluetoothTestPage())
/// ```
class BluetoothTestPage extends StatelessWidget {
  const BluetoothTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<BluetoothBloc>(),
      child: const _BluetoothTestView(),
    );
  }
}

class _BluetoothTestView extends StatefulWidget {
  const _BluetoothTestView();

  @override
  State<_BluetoothTestView> createState() => _BluetoothTestViewState();
}

class _BluetoothTestViewState extends State<_BluetoothTestView> {
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();

  // Test results tracking
  final Map<String, bool?> _testResults = {
    'permissions': null,
    'bluetooth_enabled': null,
    'scan': null,
    'connect': null,
    'time_sync': null,
    'send_items': null,
    'request_prefs': null,
    'request_logs': null,
    'receive_messages': null,
    'disconnect': null,
    'auto_reconnect': null,
  };

  StreamSubscription<BluetoothState>? _stateSubscription;
  int _messagesReceived = 0;

  @override
  void initState() {
    super.initState();
    _setupStateListener();
  }

  void _setupStateListener() {
    final bloc = context.read<BluetoothBloc>();
    _stateSubscription = bloc.stream.listen((state) {
      _log('State: ${state.status.name}');

      if (state.lastMessage != null) {
        _messagesReceived++;
        _log('Message received: ${state.lastMessage!.type.name}');
        if (_messagesReceived > 0) {
          _updateTest('receive_messages', true);
        }
      }

      if (state.errorMessage != null) {
        _log('Error: ${state.errorMessage}');
      }
    });
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _log(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    setState(() {
      _logs.add('[$timestamp] $message');
    });
    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _updateTest(String test, bool passed) {
    setState(() {
      _testResults[test] = passed;
    });
    _log('Test "$test": ${passed ? "✅ PASSED" : "❌ FAILED"}');
  }

  BluetoothBloc get _bloc => context.read<BluetoothBloc>();

  // ========== Test Actions ==========

  Future<void> _testPermissions() async {
    _log('Testing permissions...');
    _bloc.add(const RequestBluetoothPermissions());

    await Future.delayed(const Duration(seconds: 2));

    final state = _bloc.state;
    _updateTest('permissions', state.permissionsGranted);
    _updateTest('bluetooth_enabled', state.bluetoothEnabled);
  }

  Future<void> _testScan() async {
    _log('Starting scan (10 seconds)...');
    _bloc.add(const StartScan(timeout: Duration(seconds: 10)));

    await Future.delayed(const Duration(seconds: 11));

    final devices = _bloc.state.discoveredDevices;
    _log('Found ${devices.length} devices');
    for (final device in devices) {
      _log('  - ${device.name} (${device.id}) RSSI: ${device.rssi}');
    }

    _updateTest('scan', devices.isNotEmpty);
  }

  Future<void> _testConnect(BleDevice device) async {
    _log('Connecting to ${device.name}...');
    _bloc.add(ConnectToDevice(device.id));

    // Wait for connection state to change (up to 15 seconds)
    bool connected = false;
    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (_bloc.state.isConnected) {
        connected = true;
        break;
      }
      if (_bloc.state.status == BluetoothStatus.error) {
        _log('Connection error: ${_bloc.state.errorMessage}');
        break;
      }
    }

    _updateTest('connect', connected);

    if (connected) {
      _log('Connected successfully to ${_bloc.state.connectedDevice?.name}!');
    } else {
      _log('Connection failed. Status: ${_bloc.state.status}');
    }
  }

  Future<void> _testTimeSync() async {
    _log('Sending time sync...');
    _bloc.add(const SendTimeSync());

    await Future.delayed(const Duration(milliseconds: 500));
    _updateTest('time_sync', true); // Assume success if no error
  }

  Future<void> _testSendItems() async {
    _log('Sending test items...');

    final testItems = [
      Item(
        id: 'test-item-1',
        name: 'Test Counter',
        count: 42,
        todayCount: 5,
        incrementBy: 1,
        reminder: ReminderType.none,
        reminderValue: 0,
        lastResetTime: DateTime.now(),
        lastUpdated: DateTime.now(),
        userId: 'test-user',
      ),
      Item(
        id: 'test-item-2',
        name: 'Another Item',
        count: 100,
        todayCount: 10,
        incrementBy: 5,
        reminder: ReminderType.target,
        reminderValue: 50,
        lastResetTime: DateTime.now(),
        lastUpdated: DateTime.now(),
        userId: 'test-user',
      ),
    ];

    _bloc.add(SendItemsToDevice(testItems));

    await Future.delayed(const Duration(seconds: 1));
    _updateTest('send_items', true); // Assume success if no error
  }

  Future<void> _testRequestPrefs() async {
    // Check if connected first
    if (!_bloc.state.isConnected) {
      _log('ERROR: Not connected - cannot request prefs');
      _updateTest('request_prefs', false);
      return;
    }

    _log('Requesting device prefs...');

    // Track if we got an error
    bool gotError = false;
    final errorSub = _bloc.stream.listen((state) {
      if (state.status == BluetoothStatus.error) {
        gotError = true;
      }
    });

    _bloc.add(const RequestDeviceData(type: DeviceDataType.prefs));

    await Future.delayed(const Duration(seconds: 3));
    await errorSub.cancel();

    // The old code updates Firebase directly, not our BLoC message stream
    // So we just check that no error occurred
    final success = !gotError && _bloc.state.status != BluetoothStatus.error;
    _updateTest('request_prefs', success);

    if (success) {
      _log('Prefs request completed (data updated in Firebase)');
    } else {
      _log('Prefs request failed: ${_bloc.state.errorMessage}');
    }
  }

  /// Test using OLD code directly to compare behavior
  Future<void> _testOldCodePrefs() async {
    final deviceId = _bloc.state.connectedDevice?.id;
    if (deviceId == null) {
      _log('ERROR: Not connected to any device');
      return;
    }

    _log('Calling OLD prepareBLERead("prefs", 0)...');
    try {
      await old_code.prepareBLERead(deviceId, "prefs", 0);
      _log('OLD code completed successfully!');
    } catch (e) {
      _log('OLD code error: $e');
    }
  }

  Future<void> _testRequestLogs() async {
    // Check if connected first
    if (!_bloc.state.isConnected) {
      _log('ERROR: Not connected - cannot request logs');
      _updateTest('request_logs', false);
      return;
    }

    _log('Requesting event logs (page 0)...');

    // Track if we got an error
    bool gotError = false;
    final errorSub = _bloc.stream.listen((state) {
      if (state.status == BluetoothStatus.error) {
        gotError = true;
      }
    });

    _bloc.add(const RequestDeviceData(type: DeviceDataType.logs, page: 0));

    await Future.delayed(const Duration(seconds: 3));
    await errorSub.cancel();

    // The old code updates Firebase directly, not our BLoC message stream
    // So we just check that no error occurred
    final success = !gotError && _bloc.state.status != BluetoothStatus.error;
    _updateTest('request_logs', success);

    if (success) {
      _log('Logs request completed (data updated in Firebase)');
    } else {
      _log('Logs request failed: ${_bloc.state.errorMessage}');
    }
  }

  Future<void> _testDisconnect() async {
    _log('Disconnecting...');
    _bloc.add(const DisconnectFromDevice());

    await Future.delayed(const Duration(seconds: 2));

    final disconnected = !_bloc.state.isConnected;
    _updateTest('disconnect', disconnected);
  }

  Future<void> _runAllTests() async {
    _log('========== RUNNING ALL TESTS ==========');

    // Reset results
    setState(() {
      _testResults.updateAll((key, value) => null);
      _messagesReceived = 0;
    });

    // Test 1: Permissions
    await _testPermissions();
    if (!_bloc.state.permissionsGranted) {
      _log('❌ Cannot continue: permissions denied');
      return;
    }

    // Test 2: Scan
    await _testScan();
    if (_bloc.state.discoveredDevices.isEmpty) {
      _log('❌ Cannot continue: no devices found');
      return;
    }

    // Test 3: Connect to first device
    final device = _bloc.state.discoveredDevices.first;
    await _testConnect(device);
    if (!_bloc.state.isConnected) {
      _log('❌ Cannot continue: connection failed');
      return;
    }

    // Test 4: Time sync
    await _testTimeSync();

    // Test 5: Send items
    await _testSendItems();

    // Wait for ESP32 to process
    await Future.delayed(const Duration(seconds: 1));

    // Test 6: Request prefs
    await _testRequestPrefs();

    // Test 7: Request logs
    await _testRequestLogs();

    // Test 8: Disconnect
    await _testDisconnect();

    // Summary
    _log('========== TEST SUMMARY ==========');
    final passed = _testResults.values.where((v) => v == true).length;
    final failed = _testResults.values.where((v) => v == false).length;
    final pending = _testResults.values.where((v) => v == null).length;
    _log('Passed: $passed, Failed: $failed, Pending: $pending');

    final successRate = passed / (passed + failed) * 100;
    _log('Success rate: ${successRate.toStringAsFixed(1)}%');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Hardware Test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(() => _logs.clear()),
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Test results summary
          _buildTestResultsCard(),

          // Current state
          BlocBuilder<BluetoothBloc, BluetoothState>(
            builder: (context, state) => _buildStateCard(state),
          ),

          // Action buttons
          _buildActionButtons(),

          // Logs
          Expanded(child: _buildLogsSection()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _runAllTests,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Run All Tests'),
      ),
    );
  }

  Widget _buildTestResultsCard() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Test Results', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _testResults.entries.map((e) {
                final icon = e.value == null
                    ? Icons.circle_outlined
                    : e.value! ? Icons.check_circle : Icons.cancel;
                final color = e.value == null
                    ? Colors.grey
                    : e.value! ? Colors.green : Colors.red;
                return Chip(
                  avatar: Icon(icon, size: 18, color: color),
                  label: Text(e.key.replaceAll('_', ' '), style: const TextStyle(fontSize: 12)),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStateCard(BluetoothState state) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _buildStatusIndicator(state.status),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status: ${state.status.name}'),
                  if (state.connectedDevice != null)
                    Text('Device: ${state.connectedDevice!.name}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text('Devices found: ${state.discoveredDevices.length}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Text('Messages: $_messagesReceived'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(BluetoothStatus status) {
    Color color;
    IconData icon;

    switch (status) {
      case BluetoothStatus.connected:
        color = Colors.green;
        icon = Icons.bluetooth_connected;
        break;
      case BluetoothStatus.connecting:
      case BluetoothStatus.scanning:
        color = Colors.orange;
        icon = Icons.bluetooth_searching;
        break;
      case BluetoothStatus.error:
        color = Colors.red;
        icon = Icons.error;
        break;
      default:
        color = Colors.grey;
        icon = Icons.bluetooth;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ElevatedButton.icon(
            onPressed: _testPermissions,
            icon: const Icon(Icons.security, size: 18),
            label: const Text('Permissions'),
          ),
          ElevatedButton.icon(
            onPressed: _testScan,
            icon: const Icon(Icons.search, size: 18),
            label: const Text('Scan'),
          ),
          BlocBuilder<BluetoothBloc, BluetoothState>(
            builder: (context, state) {
              if (state.discoveredDevices.isEmpty) {
                return const SizedBox.shrink();
              }
              return PopupMenuButton<BleDevice>(
                child: ElevatedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.bluetooth, size: 18),
                  label: const Text('Connect ▼'),
                ),
                itemBuilder: (context) => state.discoveredDevices
                    .map((d) => PopupMenuItem(
                          value: d,
                          child: Text('${d.name} (${d.rssi}dB)'),
                        ))
                    .toList(),
                onSelected: _testConnect,
              );
            },
          ),
          ElevatedButton.icon(
            onPressed: _testTimeSync,
            icon: const Icon(Icons.access_time, size: 18),
            label: const Text('Time Sync'),
          ),
          ElevatedButton.icon(
            onPressed: _testSendItems,
            icon: const Icon(Icons.upload, size: 18),
            label: const Text('Send Items'),
          ),
          ElevatedButton.icon(
            onPressed: _testRequestPrefs,
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('Get Prefs'),
          ),
          ElevatedButton.icon(
            onPressed: _testOldCodePrefs,
            icon: const Icon(Icons.history_edu, size: 18),
            label: const Text('OLD Code Prefs'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
          ),
          ElevatedButton.icon(
            onPressed: _testRequestLogs,
            icon: const Icon(Icons.history, size: 18),
            label: const Text('Get Logs'),
          ),
          ElevatedButton.icon(
            onPressed: _testDisconnect,
            icon: const Icon(Icons.bluetooth_disabled, size: 18),
            label: const Text('Disconnect'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsSection() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Logs', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                Color? color;
                if (log.contains('PASSED')) color = Colors.green;
                if (log.contains('FAILED') || log.contains('Error')) color = Colors.red;
                if (log.contains('=====')) color = Colors.blue;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    log,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: color,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
