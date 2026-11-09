import 'package:flutter/material.dart';
import 'services/player_service.dart';
import 'screens/home_screen.dart';
import 'config/app_colors.dart';

// Desliza la pantalla nueva desde la derecha, siempre opaca, sin atenuar
// ni desplazar la pantalla anterior (evita el "fundido" que dejaba ver
// la pantalla previa a través de la nueva).
class _SlideInPageTransitionsBuilder extends PageTransitionsBuilder {
  const _SlideInPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final slide = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
    return SlideTransition(position: slide, child: child);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PlayerService().init();
  runApp(const AudioApp());
}

class AudioApp extends StatelessWidget {
  const AudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mamusi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 63, 0, 100), //3F0064
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color.fromARGB(255, 63, 0, 100),
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          scrolledUnderElevation: 0,
          backgroundColor: AppColors.purpleMid,
          surfaceTintColor: Colors.transparent,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _SlideInPageTransitionsBuilder(),
            TargetPlatform.iOS: _SlideInPageTransitionsBuilder(),
          },
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
