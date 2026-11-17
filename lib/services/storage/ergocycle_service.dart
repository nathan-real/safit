import 'package:flutter/foundation.dart';

import '../../models/ergocycle_parameters.dart';
import 'local_store.dart';

/// Caractéristiques de l'ergocycle, réglées par l'expérimentateur.
abstract interface class ErgocycleService {
  ValueListenable<ErgocycleParameters> get parameters;

  Future<void> load();
  Future<void> save(ErgocycleParameters parameters);

  /// Revient aux valeurs provisoires.
  Future<void> reset();
  void dispose();
}

/// Réglages gardés en mémoire seulement (tests automatisés).
class MemoryErgocycleService implements ErgocycleService {
  final _parameters = ValueNotifier(ErgocycleParameters.provisionalDefaults);

  @override
  ValueListenable<ErgocycleParameters> get parameters => _parameters;

  @override
  Future<void> load() async {}

  @override
  Future<void> save(ErgocycleParameters parameters) async => _parameters.value = parameters;

  @override
  Future<void> reset() async => _parameters.value = ErgocycleParameters.provisionalDefaults;

  @override
  void dispose() => _parameters.dispose();
}

/// Réglages enregistrés sur le téléphone.
class LocalErgocycleService implements ErgocycleService {
  LocalErgocycleService(this._store);

  static const _file = 'ergocycle';

  final LocalStore _store;
  final _parameters = ValueNotifier(ErgocycleParameters.provisionalDefaults);

  @override
  ValueListenable<ErgocycleParameters> get parameters => _parameters;

  @override
  Future<void> load() async {
    final json = await _store.read(_file);
    if (json is Map<String, Object?>) _parameters.value = ErgocycleParameters.fromJson(json);
  }

  @override
  Future<void> save(ErgocycleParameters parameters) async {
    _parameters.value = parameters;
    await _store.write(_file, parameters.toJson());
  }

  @override
  Future<void> reset() async {
    _parameters.value = ErgocycleParameters.provisionalDefaults;
    await _store.delete(_file);
  }

  @override
  void dispose() => _parameters.dispose();
}
