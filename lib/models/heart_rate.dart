import 'sensor_connection.dart';

class HeartRateDevice {
  const HeartRateDevice({required this.id, required this.name});

  final String id;
  final String name;
}

/// Une mesure reçue de la ceinture.
class HeartRateSample {
  const HeartRateSample({
    required this.timestamp,
    required this.bpm,
    this.rrIntervalsMs = const [],
  });

  final DateTime timestamp;
  final int bpm;

  /// Intervalles RR (ms) reçus avec cette mesure, pour l'analyse a posteriori.
  final List<int> rrIntervalsMs;
}

/// État courant de la ceinture, tel qu'affiché par l'interface.
class HeartRateState {
  const HeartRateState({
    this.connection = SensorConnection.disconnected,
    this.device,
    this.bpm,
    this.batteryPercent,
    this.foundDevices = const [],
  });

  final SensorConnection connection;
  final HeartRateDevice? device;
  final int? bpm;
  final int? batteryPercent;

  /// Ceintures trouvées lors de la dernière recherche.
  final List<HeartRateDevice> foundDevices;

  bool get isConnected => connection == SensorConnection.connected;

  HeartRateState copyWith({
    SensorConnection? connection,
    HeartRateDevice? device,
    int? bpm,
    int? batteryPercent,
    List<HeartRateDevice>? foundDevices,
  }) {
    return HeartRateState(
      connection: connection ?? this.connection,
      device: device ?? this.device,
      bpm: bpm ?? this.bpm,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      foundDevices: foundDevices ?? this.foundDevices,
    );
  }
}
