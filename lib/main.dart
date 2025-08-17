//////////////////////////////////  START OF CODE FOR lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Import Pages
//import 'pages/home_page.dart';
import 'splash_page.dart';

// Import Models and Services for DI setup
import 'models/app_language.dart';
import 'services/tour_data_service.dart';
import 'services/location_service.dart';
import 'services/audio_service.dart';
import 'services/tour_proximity_service.dart';
import 'services/tour_state_service.dart';
import 'services/tour_playback_service.dart';
import 'view_models/home_page_view_model.dart';

void main() {
  runApp(const MargheritaApp());
}

class MargheritaApp extends StatelessWidget {
  const MargheritaApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MultiProvider is the single source of truth for creating and providing
    // our services and view models to the entire application.
    return MultiProvider(
      providers: [
        // --- Independent Services (Level 0) ---
        Provider<TourDataService>(create: (_) => TourDataService()),
        Provider<LocationService>(create: (_) => LocationService()),
        Provider<TourProximityService>(create: (_) => TourProximityService()),
        Provider<AudioService>(
          create: (_) => AudioService(),
          dispose: (_, service) => service.dispose(),
        ),

        // --- Dependent Services (Level 1) ---
        // These use ProxyProviders because they depend on the services above.
        ProxyProvider<TourDataService, TourStateService>(
          update: (_, tourDataService, __) => TourStateService(tourDataService: tourDataService),
          dispose: (_, service) => service.dispose(),
        ),
        ProxyProvider4<LocationService, AudioService, TourProximityService, TourStateService, TourPlaybackService>(
          update: (_, location, audio, proximity, state, __) => TourPlaybackService(
            locationService: location,
            audioService: audio,
            tourProximityService: proximity,
            tourStateService: state,
          ),
          dispose: (_, service) => service.dispose(),
        ),

        // --- ViewModel (Level 2) ---
        // This depends on multiple services. We use a ChangeNotifierProxyProvider
        // because our ViewModel is a ChangeNotifier.
        ChangeNotifierProxyProvider5<TourDataService, AudioService, TourPlaybackService, TourProximityService, TourStateService, HomePageViewModel>(
          create: (context) {
            // Initial configuration values now live here, centrally.
            const initialLanguage = AppLanguage.it;
            const isEditMode = true; // Could be loaded from SharedPreferences

            // We use context.read to get the services that were just created above.
            return HomePageViewModel(
              tourDataService: context.read<TourDataService>(),
              audioService: context.read<AudioService>(),
              tourPlaybackService: context.read<TourPlaybackService>(),
              tourProximityService: context.read<TourProximityService>(),
              tourStateService: context.read<TourStateService>(),
              initialLanguage: initialLanguage,
              isEditMode: isEditMode,
            );
          },
          // The update callback is required but not complex here, as our services don't get replaced.
          update: (_, tourData, audio, playback, proximity, state, viewModel) => viewModel!,
        ),
      ],
      child: MaterialApp(
        title: 'Margherita',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          brightness: Brightness.dark,
        ),
        // The SplashPage (and subsequently HomePage) can now access all the providers
        // defined above because they are descendants in the widget tree.
        home: const SplashPage(),
      ),
    );
  }
}

// NOTE: The `SplashPage` would also be simplified. Its navigation call
// would no longer need to pass arguments to HomePage:
// Navigator.pushReplacement(context, MaterialPageRoute(
//     builder: (context) => const HomePage(), // No more arguments!
// ));
//////////////////////////////////  END OF FILE