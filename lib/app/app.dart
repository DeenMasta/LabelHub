import 'package:flutter/material.dart';

import 'router.dart';
import 'theme/app_theme.dart';

class LabelHubApp extends StatelessWidget {
  const LabelHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'LabelHub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
