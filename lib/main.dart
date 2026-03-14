import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/wallet_provider.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => WalletProvider(),
      child: const MorpheusApp(),
    ),
  );
}

class MorpheusApp extends StatelessWidget {
  const MorpheusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Morpheus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0a0e0a),
        fontFamily: 'monospace',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF7931A),
          secondary: Color(0xFF00ff41),
          surface: Color(0xFF0a0e0a),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0a0e0a),
          foregroundColor: Color(0xFF00ff41),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'monospace',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00ff41),
            letterSpacing: 2,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: const Color(0xFFF7931A),
            side: const BorderSide(
                color: Color(0xFFF7931A), width: 2),
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero),
            textStyle: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
            padding: const EdgeInsets.symmetric(
                vertical: 14, horizontal: 20),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: Color(0xFF00ff41)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: Color(0xFF00ff41)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide:
                BorderSide(color: Color(0xFFF7931A), width: 2),
          ),
          labelStyle: TextStyle(
              color: Color(0xFF00cc33),
              fontFamily: 'monospace'),
          hintStyle: TextStyle(
              color: Color(0xFF005511),
              fontFamily: 'monospace'),
          prefixIconColor: Color(0xFFF7931A),
          suffixIconColor: Color(0xFF00ff41),
        ),
        dividerColor: Color(0xFF00ff41),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
