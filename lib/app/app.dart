import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../features/home/home_screen.dart';

class GeoPointApp extends StatelessWidget {
  const GeoPointApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final TextTheme baseTextTheme =
        ThemeData.light().textTheme;

    return MaterialApp(
      title: 'GeoPoint',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor:
            const Color(0xFF071B3A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF176BFF),
          brightness: Brightness.light,
        ),

        /*
         * Nunito Sans devient la police principale :
         * plus ronde et plus chaleureuse que Roboto.
         */
        textTheme:
            GoogleFonts.nunitoSansTextTheme(
          baseTextTheme,
        ),

        filledButtonTheme:
            FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor:
                const Color(0xFF176BFF),
            foregroundColor: Colors.white,
            minimumSize:
                const Size(
              double.infinity,
              56,
            ),
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(18),
            ),
            textStyle:
                GoogleFonts.fredoka(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),

        appBarTheme: AppBarTheme(
          backgroundColor:
              const Color(0xFF071B3A),
          foregroundColor: Colors.white,
          centerTitle: true,
          titleTextStyle:
              GoogleFonts.fredoka(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}