import 'package:flutter/foundation.dart';

import '../../models/test_protocol.dart';
import '../../models/test_session.dart';
import 'test_data_service.dart';

/// Choisit au lancement de chaque test entre le vrai test (caméra 240 i/s
/// prête) et le test simulé (émulateur, téléphone sans mode haute vitesse,
/// zone de détection pas réglée).
class AutoTestService implements TestDataService {
  AutoTestService({
    required this._real,
    required TestDataService simulated,
    required this._cameraReady,
  })  : _simulated = simulated,
        _active = simulated {
    _real.session.addListener(_forwardReal);
    _simulated.session.addListener(_forwardSimulated);
  }

  final TestDataService _real;
  final TestDataService _simulated;
  final bool Function() _cameraReady;
  TestDataService _active;

  final _session = ValueNotifier<TestSession?>(null);

  void _forwardReal() {
    if (identical(_active, _real)) _session.value = _real.session.value;
  }

  void _forwardSimulated() {
    if (identical(_active, _simulated)) _session.value = _simulated.session.value;
  }

  @override
  ValueListenable<TestSession?> get session => _session;

  @override
  bool get isSimulation => _active.isSimulation;

  @override
  Future<void> arm(TestProtocol protocol, {int bout = 0}) {
    _active.reset();
    _active = _cameraReady() ? _real : _simulated;
    return _active.arm(protocol, bout: bout);
  }

  @override
  Future<void> stop() => _active.stop();

  @override
  Future<void> abort() => _active.abort();

  @override
  void reset() => _active.reset();

  @override
  void dispose() {
    _real.session.removeListener(_forwardReal);
    _simulated.session.removeListener(_forwardSimulated);
    _real.dispose();
    _simulated.dispose();
    _session.dispose();
  }
}
