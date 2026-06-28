import 'package:flutter/material.dart';
import 'router.dart';
import 'theme.dart';

class MacCleanerApp extends StatelessWidget {
  const MacCleanerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MacCleaner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: goRouter,
    );
  }
}
