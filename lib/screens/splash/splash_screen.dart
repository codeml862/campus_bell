import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Shown while the saved login session is restored: white page + spinner.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: Colors.white,
    body: Center(
      child: SizedBox(
        width: 36,
        height: 36,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: AppColors.accent,
        ),
      ),
    ),
  );
}
