// START OF CODE FOR lib/languages.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // <-- THIS IS THE FIX. THE MISSING IMPORT.

import 'intro_pages.dart';
import 'models/app_language.dart';
import 'pages/home_page.dart';
import 'view_models/home_page_view_model.dart';

class LanguagePage extends StatefulWidget {
  const LanguagePage({super.key});

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  bool _isDebugModeEnabled = false;

  void _onLanguageSelected(BuildContext context, AppLanguage lang) {
    final viewModel = Provider.of<HomePageViewModel>(context, listen: false);
    viewModel.toggleEditMode(_isDebugModeEnabled);
    viewModel.changeLanguage(lang);

    if (_isDebugModeEnabled) {
      // --- NO CHANGE NEEDED HERE, USES DEFAULT isProductionMode: false ---
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else {
      // For the regular user path, we still go to intros first
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => IntroPages(language: lang)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Select Tour Language', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => _onLanguageSelected(context, AppLanguage.en),
              style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
              child: const Text('English'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _onLanguageSelected(context, AppLanguage.it),
              style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
              child: const Text('Italiano'),
            ),
            
            const SizedBox(height: 60),
            const Divider(),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Debug/Edit Mode', style: TextStyle(color: Colors.purpleAccent)),
                const SizedBox(width: 10),
                Switch(
                  value: _isDebugModeEnabled,
                  activeColor: Colors.purpleAccent,
                  onChanged: (bool value) {
                    setState(() {
                      _isDebugModeEnabled = value;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
// END OF FILE