import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'services/app_services.dart';
import 'ui/shell/app_shell.dart';

class SafitApp extends StatelessWidget {
  const SafitApp({super.key, required this.services});

  final ServiceRegistry services;

  @override
  Widget build(BuildContext context) {
    return AppServices(
      registry: services,
      child: MaterialApp(
        title: 'SAFiT',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: const AppShell(),
      ),
    );
  }
}
