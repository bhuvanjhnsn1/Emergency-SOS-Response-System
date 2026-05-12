import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../utils/constants.dart';

/// Connection state for the BLE device
enum BleConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  triggered,
  error,
}

/// Service handling all BLE communication with the ESP32-C3
class BleService extends ChangeNotifier {
  BluetoothDevice? _connectedDevice;
  BleConnectionState _state = BleConnectionState.disconnected;
  String _statusMessage = 'Idle — Waiting for SOS device';
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _characteristicSubscription;

  // Callback invoked when SOS trigger is received
  VoidCallback? onSosTriggerReceived;

  BleConnectionState get state => _state;
  String get statusMessage => _statusMessage;
  bool get isConnected => _state == BleConnectionState.connected;

  /// Start scanning for the ESP32-C3 SOS device
  Future<void> startScanning() async {
    if (_state == BleConnectionState.scanning) return;

    _updateState(BleConnectionState.scanning, 'Scanning for SOS device...');

    try {
      // Stop any previous scan
      await FlutterBluePlus.stopScan();

      // Check adapter state
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        _updateState(
          BleConnectionState.error,
          'Bluetooth is off. Please enable Bluetooth.',
        );
        return;
      }

      // Start scanning with service filter
      await FlutterBluePlus.startScan(
        withServices: [Guid(BleConstants.serviceUuid)],
        timeout: BleConstants.scanTimeout,
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen(
        (results) {
          for (final result in results) {
            // Found our ESP32 device
            _onDeviceFound(result.device);
            break;
          }
        },
        onError: (error) {
          _updateState(
            BleConnectionState.error,
            'Scan error: ${error.toString()}',
          );
        },
      );

      // Handle scan timeout
      Future.delayed(BleConstants.scanTimeout, () {
        if (_state == BleConnectionState.scanning) {
          _updateState(
            BleConnectionState.disconnected,
            'No SOS device found. Tap to retry.',
          );
        }
      });
    } catch (e) {
      _updateState(
        BleConnectionState.error,
        'Failed to start scan: ${e.toString()}',
      );
    }
  }

  /// Handle device discovery
  Future<void> _onDeviceFound(BluetoothDevice device) async {
    await FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    _connectedDevice = device;
    _updateState(BleConnectionState.connecting, 'Device found! Connecting...');
    await _connectToDevice(device);
  }

  /// Establish connection and subscribe to notifications
  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(
        timeout: BleConstants.connectionTimeout,
        autoConnect: false,
      );

      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _updateState(
            BleConnectionState.disconnected,
            'Device disconnected. Tap to reconnect.',
          );
          _cleanup();
        }
      });

      _updateState(BleConnectionState.connected, 'Connected! Listening for SOS...');

      // Discover services and subscribe to trigger characteristic
      await _discoverAndSubscribe(device);
    } catch (e) {
      _updateState(
        BleConnectionState.error,
        'Connection failed: ${e.toString()}',
      );
    }
  }

  /// Discover BLE services and subscribe to the SOS trigger characteristic
  Future<void> _discoverAndSubscribe(BluetoothDevice device) async {
    try {
      final services = await device.discoverServices();

      for (final service in services) {
        if (service.uuid.toString().toLowerCase() ==
            BleConstants.serviceUuid.toLowerCase()) {
          for (final characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() ==
                BleConstants.triggerCharacteristicUuid.toLowerCase()) {
              // Enable notifications
              await characteristic.setNotifyValue(true);

              _characteristicSubscription =
                  characteristic.onValueReceived.listen((value) {
                final decoded = utf8.decode(value);
                debugPrint('BLE Received: $decoded');

                if (decoded.contains(BleConstants.sosTriggerCommand)) {
                  _updateState(
                    BleConnectionState.triggered,
                    '🚨 SOS TRIGGERED! Executing emergency protocol...',
                  );
                  onSosTriggerReceived?.call();
                }
              });

              debugPrint('Subscribed to SOS trigger characteristic');
              return;
            }
          }
        }
      }

      _updateState(
        BleConnectionState.error,
        'SOS characteristic not found on device.',
      );
    } catch (e) {
      _updateState(
        BleConnectionState.error,
        'Service discovery failed: ${e.toString()}',
      );
    }
  }

  /// Disconnect from the current device
  Future<void> disconnect() async {
    try {
      await _connectedDevice?.disconnect();
    } catch (_) {}
    _cleanup();
    _updateState(BleConnectionState.disconnected, 'Disconnected');
  }

  void _cleanup() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _characteristicSubscription?.cancel();
    _scanSubscription = null;
    _connectionSubscription = null;
    _characteristicSubscription = null;
    _connectedDevice = null;
  }

  void _updateState(BleConnectionState newState, String message) {
    _state = newState;
    _statusMessage = message;
    notifyListeners();
  }

  /// Reset state after emergency protocol completes
  void resetAfterEmergency() {
    _updateState(
      BleConnectionState.disconnected,
      'Emergency protocol completed. Tap to reconnect.',
    );
    _cleanup();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
