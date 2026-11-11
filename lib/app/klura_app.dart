import 'package:flutter/material.dart';
import 'package:klura/app/klura_theme.dart';
import 'package:klura/home/home_screen.dart';

class KluraApp extends StatelessWidget {
  const KluraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Klura',
      debugShowCheckedModeBanner: false,
      theme: buildKluraTheme(Brightness.light),
      darkTheme: buildKluraTheme(Brightness.dark),
      home: HomeScreen(today: DateTime.now()),
    );
  }
}
