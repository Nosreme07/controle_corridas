import 'package:flutter/material.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  // --- CONTROLADORES ABA 1 (COMBUSTÍVEL) ---
  final _gasController = TextEditingController();
  final _etaController = TextEditingController();
  String _resCombustivel = "";
  Color _corCombustivel = Colors.black;

  // --- CONTROLADORES ABA 2 (VALOR KM) ---
  final _valorCorridaController = TextEditingController();
  final _kmCorridaController = TextEditingController();
  String _resViagem = "";
  Color _corViagem = Colors.black;

  // --- CONTROLADORES ABA 3 (META) ---
  final _metaDiariaController = TextEditingController();
  final _ganhoAtualController = TextEditingController();
  final _mediaPorCorridaController = TextEditingController();
  String _resMeta = "";

  // --- FUNÇÕES DE CÁLCULO ---

  void _calcularCombustivel() {
    double? gas = double.tryParse(_gasController.text.replaceAll(',', '.'));
    double? eta = double.tryParse(_etaController.text.replaceAll(',', '.'));

    if (gas == null || eta == null) {
      setState(() => _resCombustivel = "Preencha os dois valores!");
      return;
    }

    // Regra dos 70%
    double relacao = eta / gas;
    setState(() {
      if (relacao < 0.7) {
        _resCombustivel = "Abasteça com ETANOL 🟢\n(Rendimento compensa)";
        _corCombustivel = Colors.green;
      } else {
        _resCombustivel = "Abasteça com GASOLINA 🔴\n(Etanol está caro)";
        _corCombustivel = Colors.red;
      }
    });
  }

  void _calcularViagem() {
    double? valor = double.tryParse(_valorCorridaController.text.replaceAll(',', '.'));
    double? km = double.tryParse(_kmCorridaController.text.replaceAll(',', '.'));

    if (valor == null || km == null || km == 0) return;

    double valorPorKm = valor / km;

    setState(() {
      String msg = "R\$ ${valorPorKm.toStringAsFixed(2)} por Km";
      if (valorPorKm >= 2.0) {
        _resViagem = "$msg\nExcelente Corrida! 🤑";
        _corViagem = Colors.green;
      } else if (valorPorKm >= 1.5) {
        _resViagem = "$msg\nCorrida Razoável 😐";
        _corViagem = Colors.orange;
      } else {
        _resViagem = "$msg\nCorrida Ruim (Prejuízo) 😡";
        _corViagem = Colors.red;
      }
    });
  }

  void _calcularMeta() {
    double? meta = double.tryParse(_metaDiariaController.text.replaceAll(',', '.'));
    double? ganho = double.tryParse(_ganhoAtualController.text.replaceAll(',', '.')) ?? 0.0;
    double? media = double.tryParse(_mediaPorCorridaController.text.replaceAll(',', '.'));

    if (meta == null || media == null || media == 0) return;

    double falta = meta - ganho;
    if (falta <= 0) {
      setState(() => _resMeta = "Parabéns! Meta batida! 🎉");
      return;
    }

    int corridasRestantes = (falta / media).ceil(); // Arredonda pra cima

    setState(() {
      _resMeta = "Faltam R\$ ${falta.toStringAsFixed(2)}\n"
          "Você precisa de aproximadamente\n"
          "$corridasRestantes corridas de R\$ ${media.toStringAsFixed(2)}";
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Calculadora do Motorista"),
          backgroundColor: Colors.amber,
          centerTitle: true,
          bottom: const TabBar(
            indicatorColor: Colors.black,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.local_gas_station), text: "Combustível"),
              Tab(icon: Icon(Icons.map), text: "Avaliar Km"),
              Tab(icon: Icon(Icons.flag), text: "Meta Diária"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ABA 1: COMBUSTÍVEL
            _buildTabContent(
              children: [
                _buildInput(_gasController, "Preço da Gasolina", Icons.local_fire_department),
                _buildInput(_etaController, "Preço do Etanol", Icons.water_drop),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _calcularCombustivel,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                  child: const Text("QUAL COMPENSA?", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
                Text(_resCombustivel, textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _corCombustivel)),
              ],
            ),

            // ABA 2: AVALIAR VIAGEM
            _buildTabContent(
              children: [
                _buildInput(_valorCorridaController, "Valor da Corrida (R\$)", Icons.attach_money),
                _buildInput(_kmCorridaController, "Distância Total (Km)", Icons.add_road),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _calcularViagem,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                  child: const Text("VALE A PENA?", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
                Text(_resViagem, textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _corViagem)),
              ],
            ),

            // ABA 3: META
            _buildTabContent(
              children: [
                _buildInput(_metaDiariaController, "Sua Meta Diária (R\$)", Icons.flag),
                _buildInput(_ganhoAtualController, "Quanto já ganhou hoje? (R\$)", Icons.account_balance_wallet),
                _buildInput(_mediaPorCorridaController, "Média por corrida (Ex: 15.00)", Icons.timeline),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _calcularMeta,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                  child: const Text("CALCULAR RESTANTE", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
                Text(_resMeta, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent({required List<Widget> children}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}