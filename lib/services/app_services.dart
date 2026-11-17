import 'dart:io';

import 'package:flutter/widgets.dart';

import '../models/camera_state.dart';
import 'ble/heart_rate_service.dart';
import 'ble/mock_heart_rate_service.dart';
import 'camera/camera_service.dart';
import 'camera/mock_camera_service.dart';
import 'camera/real_camera_service.dart';
import 'storage/account_service.dart';
import 'storage/ergocycle_service.dart';
import 'storage/local_account_service.dart';
import 'storage/local_results_service.dart';
import 'storage/local_store.dart';
import 'storage/mock_account_service.dart';
import 'storage/mock_results_service.dart';
import 'storage/results_service.dart';
import 'test/auto_test_service.dart';
import 'test/mock_test_service.dart';
import 'test/real_test_service.dart';
import 'test/test_data_service.dart';

/// Regroupe les services de l'app. C'est le seul endroit où l'on choisit
/// entre les versions simulées et réelles.
class ServiceRegistry {
  const ServiceRegistry({
    required this.heartRate,
    required this.camera,
    required this.testData,
    required this.results,
    required this.account,
    required this.ergocycle,
  });

  /// Tout simulé, en mémoire. [live] à faux coupe les minuteries (tests
  /// automatisés). [account] : état du compte au lancement.
  factory ServiceRegistry.mock({bool live = true, AccountStatus account = AccountStatus.loggedIn}) {
    return ServiceRegistry(
      heartRate: MockHeartRateService(live: live),
      camera: MockCameraService(),
      testData: MockTestService(),
      results: MockResultsService(),
      account: MockAccountService(initial: account),
      ergocycle: MemoryErgocycleService(),
    );
  }

  /// Ce qu'utilise l'app : compte, historique et réglages enregistrés sur le
  /// téléphone ; vraie caméra sur Android. La ceinture reste simulée en
  /// attendant la version Bluetooth.
  factory ServiceRegistry.forDevice() {
    final store = LocalStore.appDocuments();
    final heartRate = MockHeartRateService();
    final ergocycle = LocalErgocycleService(store);
    final CameraService camera;
    final TestDataService testData;
    if (Platform.isAndroid) {
      camera = RealCameraService();
      testData = AutoTestService(
        real: RealTestService(heartRate: heartRate, ergocycle: ergocycle.parameters),
        simulated: MockTestService(),
        cameraReady: () {
          final c = camera.state.value;
          return c.highSpeed && c.status == CameraStatus.ready;
        },
      );
    } else {
      camera = MockCameraService();
      testData = MockTestService();
    }
    return ServiceRegistry(
      heartRate: heartRate,
      camera: camera,
      testData: testData,
      results: LocalResultsService(store),
      account: LocalAccountService(store),
      ergocycle: ergocycle,
    );
  }

  final HeartRateService heartRate;
  final CameraService camera;
  final TestDataService testData;
  final ResultsService results;
  final AccountService account;
  final ErgocycleService ergocycle;

  /// Relit ce qui est enregistré sur le téléphone (compte, réglages).
  Future<void> load() async {
    await Future.wait([account.load(), ergocycle.load()]);
  }

  void dispose() {
    heartRate.dispose();
    camera.dispose();
    testData.dispose();
    account.dispose();
    ergocycle.dispose();
  }
}

/// Rend les services accessibles à tous les écrans :
/// `AppServices.of(context).heartRate`.
class AppServices extends InheritedWidget {
  const AppServices({super.key, required this.registry, required super.child});

  final ServiceRegistry registry;

  static ServiceRegistry of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppServices>();
    assert(scope != null, 'AppServices introuvable dans l\'arbre de widgets');
    return scope!.registry;
  }

  @override
  bool updateShouldNotify(AppServices oldWidget) => registry != oldWidget.registry;
}
