// START OF CODE FOR lib/intro_pages.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/app_language.dart';
import 'pages/home_page.dart';
import 'view_models/home_page_view_model.dart';

// The data map for intro pages (no changes here)
const Map<AppLanguage, List<Map<String, dynamic>>> _introData = {
  AppLanguage.it: [
    {
      'title': 'BENVENUTO',
      'imagePath': 'assets/images/1.png',
      'description': 'Il sentiero di Santa Rita offre un\'esperienza sonora immersiva che ti offrirà una finestra unica nel mondo di questa donna.\n\nRita è il nome con cui oggi la conosciamo, ma all\'epoca lei era, semplicemente, Margherita.',
    },
    {
      'title': null,
      'imagePath': 'assets/images/2.png',
      'description': 'Con l\'aiuto di questa applicazione e delle cuffie/auricolari, ascolterete paesaggi sonori evocativi che si attiveranno automaticamente nei luoghi chiave lungo il cammino, trasportandovi indietro nel tempo e facendovi rivivere i momenti salienti dell\'esistenza della Santa.',
      'secondaryActionText': 'NON HO GLI AURICOLARI',
    },
    {
      'title': null,
      'imagePath': 'assets/images/3.png',
      'description': 'Non dovrete fare nient\'altro che camminare con l\'app attiva: il GPS rileverà la vostra posizione e attiverà le sonorità appropriate, come se steste ascoltando la colonna sonora della vita di Rita mentre percorrete le sue orme.',
    },
    {
      'title': null,
      'imagePath': 'assets/images/4.png',
      'description': 'Il nostro intento è arricchire il vostro pellegrinaggio con un tocco di innovazione che vi permetterà un collegamento più profondo e intimo con la storia di Santa Rita senza mai perdere il contatto con la natura, la spiritualità e il sacro percorso che state compiendo.\n\nLasciatevi guidare e affidatevi a questa esperienza unica: il Cammino Sonoro vi aspetta!',
    }
  ],
  AppLanguage.en: [
    {
      'title': 'WELCOME',
      'imagePath': 'assets/images/1.png',
      'description': 'The path of Saint Rita offers an immersive sound experience that will give you a unique window into the world of this woman.\n\nRita is the name we know her by today, but at the time she was, simply, Margherita.',
    },
    {
      'title': 'ENG',
      'imagePath': 'assets/images/2.png',
      'description': 'With the help of this application and headphones, you will listen to evocative soundscapes that will be automatically activated in key places along the path, transporting you back in time and allowing you to relive the salient moments of the Saint\'s existence.',
      'secondaryActionText': 'I DON\'T HAVE HEADPHONES',
    },
    {
      'title': 'ENG',
      'imagePath': 'assets/images/3.png',
      'description': 'You won\'t have to do anything but walk with the app active: the GPS will detect your position and activate the appropriate sounds, as if you were listening to the soundtrack of Rita\'s life while walking in her footsteps.',
    },
    {
      'title': 'ENG',
      'imagePath': 'assets/images/4.png',
      'description': 'Our intent is to enrich your pilgrimage with a touch of innovation that will allow a deeper and more intimate connection with the story of Saint Rita without ever losing contact with nature, spirituality, and the sacred path you are taking.\n\nLet yourself be guided and entrust yourself to this unique experience: the Sound Path awaits you!',
    }
  ],
};


class IntroPages extends StatefulWidget {
  final AppLanguage language;

  const IntroPages({super.key, required this.language});

  @override
  State<IntroPages> createState() => _IntroPagesState();
}

class _IntroPagesState extends State<IntroPages> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      if (mounted) {
        setState(() {
          _currentPage = _pageController.page?.round() ?? 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

    void _navigateToHome() {
    final viewModel = Provider.of<HomePageViewModel>(context, listen: false);
    viewModel.changeLanguage(widget.language);
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        // --- SET PRODUCTION MODE TO TRUE ---
        builder: (context) => const HomePage(isProductionMode: true),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final pages = _introData[widget.language]!;
    final bool isLastPage = _currentPage == pages.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: pages.length,
                itemBuilder: (context, index) {
                  return _buildPageContent(pageData: pages[index]);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 40.0, top: 20.0),
              child: GestureDetector(
                onTap: () {
                  if (isLastPage) {
                    _navigateToHome();
                  } else {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    color: Colors.black54,
                    size: 35,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContent({required Map<String, dynamic> pageData}) {
    final title = pageData['title'] as String?;
    final imagePath = pageData['imagePath'] as String;
    final description = pageData['description'] as String;
    final secondaryActionText = pageData['secondaryActionText'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          if (title != null)
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontFamily: 'Georgia',
                color: Colors.black,
                height: 2.0,
              ),
            ),
          Container(
            constraints: const BoxConstraints(
              maxHeight: 250,
            ),
            child: Image.asset(
              imagePath,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          if (secondaryActionText != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0E6A1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                secondaryActionText,
                style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: 12,
                ),
              ),
            ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}
// END OF FILE