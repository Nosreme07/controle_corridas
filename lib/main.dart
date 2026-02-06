import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // Opcional, para calendário em PT-BR
import './screens/home_screen.dart';

void main() => runApp(const NineNinePopApp());

class NineNinePopApp extends StatelessWidget {
  const NineNinePopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '99 Pop Control',
      debugShowCheckedModeBanner: false, // Remove a faixa "Debug"
      theme: ThemeData(
        primarySwatch: Colors.amber, // Cor base (Amarelo 99)
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.amber).copyWith(
          secondary: Colors.black87, // Cor de destaque
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.amber,
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const HomeScreen(),
      // Configuração para o app entender datas em Português (opcional)
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
    );
  }
}