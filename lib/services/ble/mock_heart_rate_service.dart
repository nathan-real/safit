import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../models/heart_rate.dart';
import '../../models/sensor_connection.dart';
import 'heart_rate_service.dart';

/// Ceinture simulée : FC autour de 72 bpm, une mesure par seconde.
class MockHeartRateService implements HeartRateService {
  MockHeartRateService({bool startConnected = true, this.live = true}) {
    if (startConnected) _setConnected(_device);
  }

  /// Si faux, aucune minuterie n'est lancée (tests automatisés).
  final bool live;

  static const _device = HeartRateDevice(id: 'A1B2C3D4', name: 'Polar H10 A1B2C3D4');

  final _state = ValueNotifier(const HeartRateState());
  final _samples = StreamController<HeartRateSample>.broadcast();
  final _random = Random();
  Timer? _timer;
  int _ticks = 0;

  @override
  ValueListenable<HeartRateState> get state => _state;

  @override
  Stream<HeartRateSample> get samples => _samples.stream;

  @override
  Future<void> scan() async {
    _state.value = _state.value.copyWith(connection: SensorConnection.searching);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    _state.value = _state.value.copyWith(
      connection: _state.value.device == null
          ? SensorConnection.disconnected
          : SensorConnection.connected,
      foundDevices: const [_device],
    );
  }

  @override
  Future<void> connect(HeartRateDevice device) async {
    _state.value = _state.value.copyWith(connection: SensorConnection.connecting);
    await Future<void>.delayed(const Duration(seconds: 1));
    _setConnected(device);
  }

  @override
  Future<void> disconnect() async {
    _timer?.cancel();
    _state.value = HeartRateState(foundDevices: _state.value.foundDevices);
  }

  void _setConnected(HeartRateDevice device) {
    _state.value = _state.value.copyWith(
      connection: SensorConnection.connected,
      device: device,
      bpm: 72,
      batteryPercent: 78,
    );
    if (live) {
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _emit());
    }
  }

  void _emit() {
    _ticks++;
    final bpm = (72 + 3 * sin(_ticks / 6) + _random.nextInt(3) - 1).round();
    final rr = (60000 / bpm).round();
    _state.value = _state.value.copyWith(bpm: bpm);
    _samples.add(HeartRateSample(timestamp: DateTime.now(), bpm: bpm, rrIntervalsMs: [rr]));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _samples.close();
    _state.dispose();
  }
}
