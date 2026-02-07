import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart'; // ADICIONADO
import 'package:firebase_auth/firebase_auth.dart'; // ADICIONADO
import 'firebase_options.dart'; // ADICIONADO (arquivo que você gerou)
import 'screens/home_screen.dart';
import './screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inicializa o Firebase (Obrigatório para o plano Blaze funcionar)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2. Verifica se o usuário está logado via Firebase (substituindo SharedPreferences)
  // O FirebaseAuth mantém a sessão ativa mesmo se fechar o app.
  User? user = FirebaseAuth.instance.currentUser;

  runApp(
    DomexApp(
      // Se user não for nulo, ele vai direto para a Home
      startScreen: user != null ? const HomeScreen() : const LoginScreen(),
    ),
  );
}

class DomexApp extends StatelessWidget {
  final Widget startScreen;

  const DomexApp({super.key, required this.startScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Domex',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.amber,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.amber,
        ).copyWith(secondary: Colors.black87),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.amber,
          iconTheme: IconThemeData(
            color: Colors.black,
          ), // Garante ícones pretos no fundo amarelo
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: startScreen,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations
            .delegate, // Adicionado para suporte completo a PT-BR
      ],
      supportedLocales: const [Locale('pt', 'BR')],
    );
  }
}
