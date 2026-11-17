import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:safit/models/athlete_profile.dart';
import 'package:safit/models/ergocycle_parameters.dart';
import 'package:safit/models/test_protocol.dart';
import 'package:safit/models/test_recording.dart';
import 'package:safit/models/test_result.dart';
import 'package:safit/models/test_session.dart';
import 'package:safit/services/storage/account_service.dart';
import 'package:safit/services/storage/ergocycle_service.dart';
import 'package:safit/services/storage/local_account_service.dart';
import 'package:safit/services/storage/local_results_service.dart';
import 'package:safit/services/storage/local_store.dart';

void main() {
  late Directory dir;
  late LocalStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('safit_test');
    store = LocalStore(Future.value(dir));
  });
  tearDown(() => dir.delete(recursive: true));

  test('Compte : création, mot de passe non stocké en clair, reconnexion', () async {
    final first = LocalAccountService(store);
    await first.load();
    expect(first.status.value, AccountStatus.noAccount);
    await first.create(const AthleteProfile(firstName: 'Hugo', lastName: 'Durand', age: 30), 'velo42');
    expect(first.status.value, AccountStatus.loggedIn);

    final saved = await File('${dir.path}/account.json').readAsString();
    expect(saved, isNot(contains('velo42')));

    // Relance de l'app : le compte est là, il faut se reconnecter.
    final again = LocalAccountService(store);
    await again.load();
    expect(again.status.value, AccountStatus.loggedOut);
    expect(again.profile.value!.fullName, 'Hugo Durand');
    expect(again.profile.value!.age, 30);
    expect(await again.login('mauvais'), isFalse);
    expect(await again.login('velo42'), isTrue);
    expect(again.status.value, AccountStatus.loggedIn);
    first.dispose();
    again.dispose();
  });

  test('Résultats et mesures brutes gardés après relance', () async {
    final result = TestResult(
      id: 'a1',
      protocol: TestProtocol.incremental,
      date: DateTime(2026, 11, 17, 14, 32),
      duration: const Duration(minutes: 5),
      avgPowerW: 150.5,
      avgHeartRateBpm: 140,
      stages: const [StageResult(index: 0, targetCadenceRpm: 40, avgCadenceRpm: 41.2)],
      provisionalErgocycle: true,
    );
    const recording = TestRecording([
      RecordedBout(
        samples: [TestSample(elapsed: Duration(milliseconds: 250), cadenceRpm: 40.5, heartRateBpm: 90)],
        decelerationCurve: [(0.0, 80.0), (1.0, 60.0)],
        decelerationSlope: -20,
        decelerationR2: 0.99,
      ),
    ]);
    await LocalResultsService(store).save(result, recording: recording);

    final reopened = LocalResultsService(store);
    final list = await reopened.listResults();
    expect(list, hasLength(1));
    expect(list.single.protocol, TestProtocol.incremental);
    expect(list.single.avgPowerW, 150.5);
    expect(list.single.stages.single.avgCadenceRpm, 41.2);
    expect(list.single.date, DateTime(2026, 11, 17, 14, 32));

    final bout = (await reopened.getRecording('a1'))!.bouts.single;
    expect(bout.samples.single.cadenceRpm, 40.5);
    expect(bout.decelerationCurve.last, (1.0, 60.0));
    expect(await reopened.getRecording('inconnu'), isNull);
  });

  test('Paramètres de l\'ergocycle : enregistrés puis remis à zéro', () async {
    final service = LocalErgocycleService(store);
    await service.load();
    expect(service.parameters.value.provisional, isTrue);
    await service.save(const ErgocycleParameters(
      flywheelMassKg: 18,
      flywheelCircumferenceM: 1.5,
      flywheelTurnsPerPedalTurn: 4,
      marksPerFlywheelTurn: 6,
      provisional: false,
    ));

    final reopened = LocalErgocycleService(store);
    await reopened.load();
    expect(reopened.parameters.value.flywheelMassKg, 18);
    expect(reopened.parameters.value.marksPerFlywheelTurn, 6);
    expect(reopened.parameters.value.provisional, isFalse);

    await reopened.reset();
    final third = LocalErgocycleService(store);
    await third.load();
    expect(third.parameters.value.provisional, isTrue);
    service.dispose();
    reopened.dispose();
    third.dispose();
  });
}
