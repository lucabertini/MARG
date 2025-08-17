//////////////////////////////////  START OF CODE FOR lib/splash_page.dart

import 'package:flutter/material.dart';
import 'languages.dart';
// ------------------------------------------------------------------------

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _navigateToLanguageSelection();
  }

  Future<void> _navigateToLanguageSelection() async {
    // A slight delay to show a splash screen, for effect.
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      // This now navigates to the LanguagePage defined in 'languages.dart'
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LanguagePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 20),
            Text('Margherita', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

//////////////////////////////////  END OF FILE