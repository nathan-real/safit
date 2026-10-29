import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/theme/app_colors.dart';
import 'services/app_services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait uniquement : le téléphone est posé à plat sur le volant,
  // une rotation automatique ferait basculer l'écran pendant le test.
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Choix des services réels ou simulés : voir ServiceRegistry.forDevice.
  runApp(SafitApp(services: ServiceRegistry.forDevice()));
}
