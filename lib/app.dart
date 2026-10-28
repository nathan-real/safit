import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'ui/shell/app_shell.dart';

class SafitApp extends StatelessWidget {
  const SafitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SAFiT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const AppShell(),
    );
  }
}
