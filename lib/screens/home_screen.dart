import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'login_screen.dart';
import 'finance_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  // Variáveis de Estado
  double? _startKm;
  double? _endKm;
  double _kmRodados = 0.0;

  @override
  void initState() {
    super.initState();
    _loadDailyMileage();
  }

  // --- CARREGAR DADOS ---
  String get _todayKey => DateFormat('yyyyMMdd').format(DateTime.now());

  Future<void> _loadDailyMileage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _startKm = prefs.getDouble('km_start_$_todayKey');
      _endKm = prefs.getDouble('km_end_$_todayKey');
      _calculateRodados();
    });
  }

  void _calculateRodados() {
    if (_startKm != null && _endKm != null) {
      _kmRodados = _endKm! - _startKm!;
    } else {
      _kmRodados = 0.0;
    }
  }

  // --- DIÁLOGOS DE AÇÃO ---

  // 1. DIÁLOGO: INICIAR O DIA (Só pede Km Inicial)
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
            labelText: 'Km Inicial (Odômetro)',
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

                // Se já tiver um final antigo (de teste), apaga para evitar erro de cálculo
                if (_endKm != null && _endKm! < val) {
                  await prefs.remove('km_end_$_todayKey');
                }

                _loadDailyMileage(); // Atualiza a tela (O botão vai mudar de cor sozinho!)
                if (!mounted) return;
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Bom trabalho! Dia iniciado.")),
                );
              }
            },
            child: const Text('INICIAR', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 2. DIÁLOGO: FINALIZAR O DIA (Só pede Km Final)
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
            Text(
              "Km Inicial: ${_startKm?.toInt() ?? '---'}",
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Km Final (Odômetro)',
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
                      content: Text("Erro: Km Final menor que Inicial!"),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                final prefs = await SharedPreferences.getInstance();
                await prefs.setDouble('km_end_$_todayKey', val);

                _loadDailyMileage();
                if (!mounted) return;
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "Dia encerrado! Rodou: ${_kmRodados.toStringAsFixed(1)} Km",
                    ),
                  ),
                );
              }
            },
            child: const Text(
              'FINALIZAR',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Função para limpar dados (Resetar dia - Opcional, útil para testes)
  void _resetDay() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('km_start_$_todayKey');
    await prefs.remove('km_end_$_todayKey');
    _loadDailyMileage();
  }

  // --- NAVEGAÇÃO ---
  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _navegarPara(Widget tela) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => tela));
  }

  // --- WIDGETS ---
  Widget _buildDailySummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black87, Colors.grey[900]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              // Botãozinho discreto para resetar o dia se precisar corrigir o inicial
              if (_startKm != null)
                InkWell(
                  onTap: () {
                    // Confirmação para resetar
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Reiniciar dia?"),
                        content: const Text(
                          "Isso apagará a Km Inicial e Final de hoje.",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Não"),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _resetDay();
                            },
                            child: const Text("Sim"),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.refresh,
                    color: Colors.white24,
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Inicial",
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  Text(
                    _startKm != null ? "${_startKm!.toInt()} Km" : "---",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Icon(Icons.arrow_forward, color: Colors.white24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    "Final",
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  Text(
                    _endKm != null ? "${_endKm!.toInt()} Km" : "---",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Você rodou hoje:",
                style: TextStyle(color: Colors.white),
              ),
              Text(
                "${_kmRodados.toStringAsFixed(1)} Km",
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required String titulo,
    required IconData icone,
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icone, size: 30, color: cor),
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
    // LÓGICA DO BOTÃO DINÂMICO
    // Se não tem StartKm -> Botão Verde (Iniciar)
    // Se TEM StartKm -> Botão Vermelho (Finalizar)
    final bool isDiaIniciado = _startKm != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'DOMEX',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        centerTitle: true,
        backgroundColor: Colors.amber,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.black),
            onPressed: _logout,
          ),
        ],
      ),

      // --- BOTÃO FLUTUANTE QUE MUDA DE COR ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isDiaIniciado ? _openEndDayDialog : _openStartDayDialog,
        backgroundColor: isDiaIniciado ? Colors.red : Colors.green,
        icon: Icon(
          isDiaIniciado ? Icons.stop : Icons.play_arrow,
          color: Colors.white,
        ),
        label: Text(
          isDiaIniciado ? "FINALIZAR DIA" : "INICIAR DIA",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Olá, ${user?.email?.split('@')[0] ?? 'Motorista'}",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              isDiaIniciado ? "Turno em andamento..." : "Pronto para começar?",
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),

            _buildDailySummaryCard(),

            const SizedBox(height: 25),
            const Text(
              "MENU RÁPIDO",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.3,
              children: [
                // Removi o botão de "Ajustar Km" do grid pois agora o FAB faz tudo.
                // Mas deixei aqui caso queira um atalho para Finanças.
                _buildMenuCard(
                  titulo: "Minhas\nFinanças",
                  icone: Icons.attach_money,
                  cor: Colors.amber[800]!,
                  onTap: () => _navegarPara(const FinanceScreen()),
                ),
                _buildMenuCard(
                  titulo: "Relatórios\n& PDF",
                  icone: Icons.picture_as_pdf,
                  cor: Colors.purple,
                  onTap: () => _navegarPara(const FinanceScreen()),
                ),
                _buildMenuCard(
                  titulo: "Histórico\nCorridas",
                  icone: Icons.history,
                  cor: Colors.blue,
                  onTap: () => ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text("Em breve!"))),
                ),
                _buildMenuCard(
                  titulo: "Perfil",
                  icone: Icons.person,
                  cor: Colors.grey,
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Perfil do Motorista")),
                  ),
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
