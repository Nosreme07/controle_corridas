import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importação necessária
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// <--- TELAS
import 'login_screen.dart';
import 'finance_screen.dart';
import 'profile_screen.dart';
import 'reports_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  User? user = FirebaseAuth.instance.currentUser;

  // Variáveis de Estado
  double? _startKm;
  double? _endKm;
  double _kmRodados = 0.0;
  String? _profileImageBase64;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  String get _todayKey => DateFormat('yyyyMMdd').format(DateTime.now());

  // Função auxiliar para pegar o início do dia atual
  DateTime _getStartOfDay() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    user = FirebaseAuth.instance.currentUser;

    if (mounted) {
      setState(() {
        _startKm = prefs.getDouble('km_start_$_todayKey');
        _endKm = prefs.getDouble('km_end_$_todayKey');
        _profileImageBase64 = prefs.getString('profile_image_base64');
        _calculateRodados();
      });
    }
  }

  void _calculateRodados() {
    if (_startKm != null && _endKm != null) {
      _kmRodados = _endKm! - _startKm!;
    } else {
      _kmRodados = 0.0;
    }
  }

  // --- DIÁLOGOS (INICIAR/FINALIZAR) ---
  // (Mantive os diálogos iguais, apenas removendo comentários para encurtar visualização)
  void _openStartDayDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.play_circle_fill, color: Colors.green),
            SizedBox(width: 10),
            Text("Iniciar Dia"),
          ],
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Km Inicial',
            border: OutlineInputBorder(),
            hintText: 'Ex: 50000',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              final val = double.tryParse(controller.text.replaceAll(',', '.'));
              if (val != null) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setDouble('km_start_$_todayKey', val);
                await prefs.remove('km_end_$_todayKey');
                _loadAllData();
                if (!mounted) return;
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('INICIAR', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openEndDayDialog() {
    final controller = TextEditingController(
      text: _endKm != null ? _endKm!.toInt().toString() : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.stop_circle, color: Colors.red),
            SizedBox(width: 10),
            Text("Finalizar Dia"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Km Inicial: ${_startKm?.toInt() ?? '---'}"),
            const SizedBox(height: 15),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Km Final',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final val = double.tryParse(controller.text.replaceAll(',', '.'));
              if (val != null) {
                if (_startKm != null && val < _startKm!) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Erro: Km Final menor que Inicial!")),
                  );
                  return;
                }
                final prefs = await SharedPreferences.getInstance();
                await prefs.setDouble('km_end_$_todayKey', val);
                _loadAllData();
                if (!mounted) return;
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("Dia finalizado! Bom descanso.")),
                );
              }
            },
            child: const Text('FINALIZAR', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _reopenDay() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('km_end_$_todayKey');
    _loadAllData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Dia reaberto! Pode continuar rodando.")),
    );
  }

  void _resetDay() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('km_start_$_todayKey');
    await prefs.remove('km_end_$_todayKey');
    _loadAllData();
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _navegarPara(Widget tela) {
    // Quando volta da tela de finanças, recarregamos os dados locais (embora o Stream cuide do financeiro)
    Navigator.push(context, MaterialPageRoute(builder: (context) => tela))
        .then((_) => _loadAllData());
  }

  // --- WIDGET DO CARD ESCURO (COM STREAM DO FIRESTORE) ---
  Widget _buildDailySummaryCard() {
    final currencyFormat =
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final startOfDay = _getStartOfDay();

    return StreamBuilder<QuerySnapshot>(
      // Escuta as movimentações DO DIA ATUAL
      stream: FirebaseFirestore.instance
          .collection('financas')
          .where('userId', isEqualTo: user?.uid)
          .where('data',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .snapshots(),
      builder: (context, snapshot) {
        double ganhosHoje = 0.00;

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final double valor = (data['valor'] ?? 0.0) as double;
            if (data['tipo'] == 'Entrada') {
              ganhosHoje += valor;
            } else {
              ganhosHoje -= valor;
            }
          }
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Título do Card ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "RESUMO DO DIA",
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  if (_startKm != null)
                    InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("Reiniciar dia?"),
                            content: const Text("Isso apagará a Km de hoje."),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text("Não")),
                              TextButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _resetDay();
                                  },
                                  child: const Text("Sim")),
                            ],
                          ),
                        );
                      },
                      child: const Icon(Icons.refresh,
                          color: Colors.white24, size: 20),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // --- Linha dos KMs ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Inicial",
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(
                        _startKm != null ? "${_startKm!.toInt()} Km" : "---",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_forward, color: Colors.white24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text("Final",
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(
                        _endKm != null ? "${_endKm!.toInt()} Km" : "---",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // --- Linha do Financeiro (ATUALIZADA PELO STREAM) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Ganhos estimados (Hoje)",
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(
                        currencyFormat.format(ganhosHoje),
                        style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 22,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.greenAccent.withOpacity(0.2),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.attach_money,
                          color: Colors.greenAccent, size: 24)),
                ],
              ),

              const Divider(color: Colors.white10, height: 30),

              // --- Total Rodado ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Você rodou hoje:",
                      style: TextStyle(color: Colors.white)),
                  Text(
                    "${_kmRodados.toStringAsFixed(1)} Km",
                    style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- WIDGET DO MENU ---
  Widget _buildMenuCard({
    required String titulo,
    IconData? icone,
    Widget? customIcon,
    required Color cor,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding:
                  customIcon != null ? EdgeInsets.zero : const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: customIcon != null
                    ? Colors.transparent
                    : cor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: customIcon ?? Icon(icone, size: 30, color: cor),
            ),
            const SizedBox(height: 10),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDiaNaoIniciado = _startKm == null;
    bool isDiaEmAndamento = _startKm != null && _endKm == null;
    bool isDiaFinalizado = _startKm != null && _endKm != null;

    String nomeExibicao = "Motorista";
    if (user != null) {
      if (user!.displayName != null && user!.displayName!.isNotEmpty) {
        nomeExibicao = user!.displayName!;
      } else if (user!.email != null) {
        nomeExibicao = user!.email!.split('@')[0];
      }
    }

    ImageProvider? profileImageProvider;
    if (_profileImageBase64 != null) {
      profileImageProvider = MemoryImage(base64Decode(_profileImageBase64!));
    }

    Color fabColor = Colors.green;
    IconData fabIcon = Icons.play_arrow;
    String fabLabel = "INICIAR DIA";
    VoidCallback fabAction = _openStartDayDialog;

    if (isDiaEmAndamento) {
      fabColor = Colors.red;
      fabIcon = Icons.stop;
      fabLabel = "FINALIZAR DIA";
      fabAction = _openEndDayDialog;
    } else if (isDiaFinalizado) {
      fabColor = Colors.orange[800]!;
      fabIcon = Icons.replay;
      fabLabel = "REABRIR DIA";
      fabAction = _reopenDay;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('DOMEX',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        centerTitle: true,
        backgroundColor: Colors.amber,
        actions: [
          IconButton(
              icon: const Icon(Icons.exit_to_app, color: Colors.black),
              onPressed: _logout),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: fabAction,
        backgroundColor: fabColor,
        icon: Icon(fabIcon, color: Colors.white),
        label: Text(fabLabel,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: profileImageProvider,
                  child: profileImageProvider == null
                      ? const Icon(Icons.person, color: Colors.grey, size: 30)
                      : null,
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Olá, ${nomeExibicao.length > 15 ? '${nomeExibicao.substring(0, 15)}...' : nomeExibicao}",
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    if (isDiaEmAndamento)
                      Text("Turno ativo 🟢",
                          style: TextStyle(
                              color: Colors.green[700],
                              fontSize: 13,
                              fontWeight: FontWeight.w500))
                    else if (isDiaFinalizado)
                      const Text("Turno finalizado 🏁",
                          style: TextStyle(
                              color: Colors.orange,
                              fontSize: 13,
                              fontWeight: FontWeight.w500))
                    else
                      Text("Offline 🔴",
                          style: TextStyle(
                              color: Colors.red[300],
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 25),
            _buildDailySummaryCard(),
            const SizedBox(height: 25),
            const Text("MENU RÁPIDO",
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.3,
              children: [
                _buildMenuCard(
                  titulo: "Movimentação",
                  icone: Icons.attach_money,
                  cor: Colors.amber[800]!,
                  onTap: () => _navegarPara(const FinanceScreen()),
                ),
                _buildMenuCard(
                  titulo: "Relatórios",
                  icone: Icons.bar_chart,
                  cor: Colors.purple,
                  onTap: () => _navegarPara(const ReportsScreen()),
                ),
                _buildMenuCard(
                  titulo: "Meu Perfil",
                  cor: Colors.grey,
                  customIcon: profileImageProvider != null
                      ? CircleAvatar(
                          radius: 25,
                          backgroundImage: profileImageProvider,
                          backgroundColor: Colors.transparent,
                        )
                      : null,
                  icone: Icons.person,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ProfileScreen()),
                    ).then((_) {
                      _loadAllData();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
