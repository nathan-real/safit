import 'package:flutter/widgets.dart';

import 'ble/heart_rate_service.dart';
import 'ble/mock_heart_rate_service.dart';
import 'camera/camera_service.dart';
import 'camera/mock_camera_service.dart';
import 'storage/mock_results_service.dart';
import 'storage/results_service.dart';
import 'test/mock_test_service.dart';
import 'test/test_data_service.dart';

/// Regroupe les services de l'app. C'est le seul endroit où l'on choisit
/// entre les versions simulées et réelles.
class ServiceRegistry {
  const ServiceRegistry({
    required this.heartRate,
    required this.camera,
    required this.testData,
    required this.results,
  });

  /// Tout simulé. [live] à faux coupe les minuteries (tests automatisés).
  factory ServiceRegistry.mock({bool live = true}) {
    return ServiceRegistry(
      heartRate: MockHeartRateService(live: live),
      camera: MockCameraService(),
      testData: MockTestService(),
      results: MockResultsService(),
    );
  }

  final HeartRateService heartRate;
  final CameraService camera;
  final TestDataService testData;
  final ResultsService results;

  void dispose() {
    heartRate.dispose();
    camera.dispose();
    testData.dispose();
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
