import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'premium_screen.dart';

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  ReceivePort port = ReceivePort();
  bool isListening = false;
  String lastRideInfo = "Aguardando chamada...";
  
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Variáveis de Controle de Acesso
  bool _isLoading = true;
  bool _hasAccess = false;
  int _diasRestantes = 0;

  @override
  void initState() {
    super.initState();
    _checkAccessAndInit();
    _initLocalNotifications();
  }

  // --- CONFIGURAÇÃO DO ALERTA LOCAL ---
  void _initLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _localNotifications.initialize(initializationSettings);
  }

  Future<void> _showResultNotification(String titulo, String corpo, Color cor) async {
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'domex_result_channel',
      'Domex Resultado',
      importance: Importance.max,
      priority: Priority.high,
      color: cor,
      styleInformation: BigTextStyleInformation(corpo),
    );
    NotificationDetails details = NotificationDetails(android: androidDetails);
    await _localNotifications.show(DateTime.now().millisecond, titulo, corpo, details);
  }

  // --- 1. VERIFICAÇÃO DE ACESSO (PREMIUM OU 30 DIAS) ---
  Future<void> _checkAccessAndInit() async {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        
        bool isPremium = false;
        // Data de criação da conta para calcular os 30 dias
        DateTime dataCriacao = user.metadata.creationTime ?? DateTime.now();

        if (doc.exists && doc.data() != null) {
          isPremium = doc.data()!['isPremium'] == true;
        }

        final agora = DateTime.now();
        final diasDeUso = agora.difference(dataCriacao).inDays;
        
        // REGRA DE ACESSO:
        if (isPremium) {
          // Se for Premium, libera tudo
          _hasAccess = true;
          _diasRestantes = 9999; // Código para "Infinito"
        } else {
          // Se não for Premium, verifica se está nos 30 dias de teste
          if (diasDeUso < 30) {
            _hasAccess = true;
            _diasRestantes = 30 - diasDeUso;
          } else {
            // Acabou o teste e não pagou
            _hasAccess = false;
            _diasRestantes = 0;
          }
        }
      } catch (e) {
        debugPrint("Erro ao verificar acesso: $e");
        _hasAccess = false; 
      }
    }

    // Se tiver acesso, inicializa o sistema de leitura
    if (_hasAccess) {
      await initPlatformState();
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // --- 2. SISTEMA DE LEITURA ---
  Future<void> initPlatformState() async {
    NotificationsListener.initialize(callbackHandle: _callback);
    IsolateNameServer.removePortNameMapping("_listener_");
    IsolateNameServer.registerPortWithName(port.sendPort, "_listener_");
    
    port.listen((message) {
      _processarNotificacao(message);
    });
  }

  @pragma('vm:entry-point')
  static void _callback(NotificationEvent evt) {
    final SendPort? send = IsolateNameServer.lookupPortByName("_listener_");
    if (send != null) send.send(evt);
  }

  void _processarNotificacao(NotificationEvent evt) {
    if (evt.packageName!.contains("uber") || evt.packageName!.contains("99") || evt.packageName!.contains("taxis99")) {
      
      String titulo = evt.title ?? "";
      String texto = evt.text ?? "";
      String fullText = "$titulo $texto";

      // Regex para encontrar Preço e Km
      RegExp regPreco = RegExp(r'R\$\s*([\d,.]+)');
      RegExp regKm = RegExp(r'([\d,.]+)\s*km');

      var matchPreco = regPreco.firstMatch(fullText);
      var matchKm = regKm.firstMatch(fullText);

      String debugInfo = "App: ${evt.packageName}\nTexto Lido: $texto";

      if (matchPreco != null && matchKm != null) {
        String sPreco = matchPreco.group(1)!.replaceAll('.', '').replaceAll(',', '.');
        String sKm = matchKm.group(1)!.replaceAll(',', '.');

        double preco = double.tryParse(sPreco) ?? 0;
        double km = double.tryParse(sKm) ?? 0;

        if (km > 0) {
          double valorPorKm = preco / km;
          _avaliarENotificar(valorPorKm, preco, km);
          debugInfo += "\n\nCÁLCULO:\nR\$ ${valorPorKm.toStringAsFixed(2)}/km";
        }
      }

      setState(() {
        lastRideInfo = debugInfo;
      });
    }
  }

  // --- REGRAS DE AVALIAÇÃO (SUAS REGRAS) ---
  void _avaliarENotificar(double valorKm, double preco, double km) {
    String msg = "R\$ ${valorKm.toStringAsFixed(2)}/km (Total: R\$ ${preco.toStringAsFixed(2)})";
    
    if (valorKm > 1.80) {
      // A partir de R$ 1,81 -> MUITO BOA (Verde)
      _showResultNotification("🤩 MUITO BOA!", msg, Colors.green);
    
    } else if (valorKm >= 1.00) {
      // De R$ 1,00 até R$ 1,80 -> BOA (Laranja)
      _showResultNotification("🙂 CORRIDA BOA", msg, Colors.orange);
    
    } else {
      // Abaixo de R$ 1,00 -> RUIM (Vermelho)
      _showResultNotification("😡 CORRIDA RUIM", msg, Colors.red);
    }
  }

  void _toggleListener() async {
    final bool? hasPermission = await NotificationsListener.hasPermission;
    if (hasPermission != true) {
      await NotificationsListener.openPermissionSettings();
      return;
    }

    bool running = await NotificationsListener.isRunning ?? false;
    if (running) {
      await NotificationsListener.stopService();
      setState(() => isListening = false);
    } else {
      await NotificationsListener.startService(
        foreground: true,
        title: "Domex Monitor",
        description: "Analisando corridas em tempo real..."
      );
      setState(() => isListening = true);
    }
  }

  // --- 3. INTERFACE ---
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // TELA DE BLOQUEIO (Só aparece se não for premium E já passou dos 30 dias)
    if (!_hasAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text("Monitor Automático")),
        body: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_clock, size: 80, color: Colors.red),
              const SizedBox(height: 20),
              const Text("Período de Teste Expirado", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 10),
              const Text("Seus 30 dias de teste acabaram. Torne-se Premium para continuar usando o monitor automático.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const PremiumScreen())).then((_) => _checkAccessAndInit());
                },
                child: const Text("DESBLOQUEAR AGORA 👑", style: TextStyle(color: Colors.amber)),
              )
            ],
          ),
        ),
      );
    }

    // TELA LIBERADA
    return Scaffold(
      appBar: AppBar(
        title: const Text("Monitor Automático"),
        backgroundColor: isListening ? Colors.green : Colors.grey,
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // AVISO DE DIAS RESTANTES (Só mostra se não for Premium vitalício)
            if (_diasRestantes < 9000)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.amber[100], borderRadius: BorderRadius.circular(10)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.info, color: Colors.orange),
                    const SizedBox(width: 10),
                    Text("Teste Grátis: $_diasRestantes dias restantes"),
                  ],
                ),
              ),

            Icon(isListening ? Icons.radar : Icons.radar_outlined, size: 80, color: isListening ? Colors.green : Colors.grey),
            const SizedBox(height: 20),
            Text(isListening ? "Monitorando..." : "Monitor Parado", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isListening ? Colors.green : Colors.grey)),
            
            const SizedBox(height: 30),
            
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[400]!)),
              child: SingleChildScrollView(
                child: Text(lastRideInfo, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Courier')),
              ),
            ),
            
            const SizedBox(height: 30),
            
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _toggleListener,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isListening ? Colors.red : Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: Text(isListening ? "PARAR MONITOR" : "INICIAR MONITOR", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            
            const SizedBox(height: 20),
            const Text("Mantenha o app aberto ou em segundo plano.\nAo receber uma notificação da Uber/99, ela aparecerá aqui.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}