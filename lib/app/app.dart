import 'package:flutter/material.dart';
import 'router.dart';
import 'theme.dart';

class MacSweepApp extends StatelessWidget {
  const MacSweepApp({super.key});

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
