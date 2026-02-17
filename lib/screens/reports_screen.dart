import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'premium_screen.dart'; // Importe a tela de venda

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  
  // Status Premium real (buscado do banco)
  bool isPremium = false; 
  bool _isLoadingStatus = true; 

  String _filtroSelecionado = 'Dia'; 
  DateTime _dataSelecionada = DateTime.now(); 

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
  }

  Future<void> _checkPremiumStatus() async {
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
        if (doc.exists && doc.data() != null) {
          if (mounted) {
            setState(() {
              isPremium = doc.data()!['isPremium'] == true;
              _isLoadingStatus = false;
            });
          }
        } else {
           if (mounted) setState(() => _isLoadingStatus = false);
        }
      } catch (e) {
        debugPrint("Erro ao verificar premium: $e");
        if (mounted) setState(() => _isLoadingStatus = false);
      }
    }
  }

  DateTime get _dataLimiteGratis => DateTime.now().subtract(const Duration(days: 30));

  bool _verificarAcesso(DateTimeRange intervalo) {
    if (isPremium) return true; 
    return intervalo.start.isAfter(_dataLimiteGratis);
  }

  DateTimeRange _getIntervaloDatas() {
    final base = DateTime(_dataSelecionada.year, _dataSelecionada.month, _dataSelecionada.day);
    
    if (_filtroSelecionado == 'Dia') {
      return DateTimeRange(
        start: base, 
        end: base.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1))
      );
    } else if (_filtroSelecionado == 'Semana') {
      final startOfWeek = base.subtract(Duration(days: base.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59));
      return DateTimeRange(start: startOfWeek, end: endOfWeek);
    } else {
      final startOfMonth = DateTime(base.year, base.month, 1);
      final startOfNextMonth = DateTime(base.year, base.month + 1, 1);
      final endOfMonth = startOfNextMonth.subtract(const Duration(milliseconds: 1));
      return DateTimeRange(start: startOfMonth, end: endOfMonth);
    }
  }

  Future<void> _gerarPDF() async {
    final intervalo = _getIntervaloDatas();
    
    if (!_verificarAcesso(intervalo)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Exportação de histórico antigo é exclusivo Premium! 👑"),
          backgroundColor: Colors.orange,
        )
      );
      return;
    }

    final pdf = pw.Document();
    
    final snapshot = await FirebaseFirestore.instance
        .collection('financas')
        .where('userId', isEqualTo: user?.uid)
        .where('data', isGreaterThanOrEqualTo: Timestamp.fromDate(intervalo.start))
        .where('data', isLessThanOrEqualTo: Timestamp.fromDate(intervalo.end))
        .orderBy('data', descending: true)
        .get();

    final docs = snapshot.docs;
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final font = await PdfGoogleFonts.nunitoExtraLight();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Relatório DOMEX", style: pw.TextStyle(font: font, fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text(_getTextoData(), style: pw.TextStyle(font: font, fontSize: 14, color: PdfColors.grey)),
                  ]
                )
              ),
              pw.SizedBox(height: 20),
              
              if (_filtroSelecionado == 'Dia') 
                _buildTableDia(docs, font, currencyFormat)
              else 
                _buildResumoAgrupado(docs, font, currencyFormat),
                
              pw.Footer(
                margin: const pw.EdgeInsets.only(top: 20),
                title: pw.Text("Gerado automaticamente pelo App Domex", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  pw.Widget _buildTableDia(List<QueryDocumentSnapshot> docs, pw.Font font, NumberFormat fmt) {
    final data = docs.map((doc) {
      final d = doc.data() as Map<String, dynamic>;
      final date = (d['data'] as Timestamp).toDate();
      
      // --- CORREÇÃO DE SEGURANÇA (INT -> DOUBLE) ---
      final val = (d['valor'] ?? 0).toDouble();

      return [
        DateFormat('HH:mm').format(date),
        d['categoria'] ?? 'Geral',
        d['tipo'],
        fmt.format(val),
      ];
    }).toList();

    return pw.Table.fromTextArray(
      headers: ['Hora', 'Categoria', 'Tipo', 'Valor'],
      data: data,
      headerStyle: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold),
      cellStyle: pw.TextStyle(font: font),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
      },
    );
  }

  pw.Widget _buildResumoAgrupado(List<QueryDocumentSnapshot> docs, pw.Font font, NumberFormat fmt) {
    Map<String, double> totais = {};
    double totalGeral = 0.0;

    for (var doc in docs) {
      final d = doc.data() as Map<String, dynamic>;
      if (d['tipo'] == 'Entrada') {
        final cat = d['categoria'] ?? 'Outros';
        
        // --- CORREÇÃO DE SEGURANÇA (INT -> DOUBLE) ---
        final val = (d['valor'] ?? 0).toDouble();
        
        totais[cat] = (totais[cat] ?? 0) + val;
        totalGeral += val;
      }
    }

    final data = totais.entries.map((e) => [e.key, fmt.format(e.value)]).toList();
    data.add(['TOTAL', fmt.format(totalGeral)]); 

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text("Resumo de Faturamento por App", style: pw.TextStyle(font: font, fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Table.fromTextArray(
          headers: ['Aplicativo', 'Total'],
          data: data,
          headerStyle: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold),
          cellStyle: pw.TextStyle(font: font),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.amber100),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerRight,
          },
        ),
      ]
    );
  }

  Future<void> _escolherData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2020), 
      lastDate: DateTime(2030),
      locale: const Locale('pt', 'BR'), 
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.purple),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _dataSelecionada) {
      setState(() {
        _dataSelecionada = picked;
      });
    }
  }

  String _getTextoData() {
    if (_filtroSelecionado == 'Dia') {
      return DateFormat('dd/MM/yyyy').format(_dataSelecionada);
    } else if (_filtroSelecionado == 'Semana') {
      final range = _getIntervaloDatas();
      return "${DateFormat('dd/MM').format(range.start)} - ${DateFormat('dd/MM').format(range.end)}";
    } else {
      return DateFormat('MMMM yyyy', 'pt_BR').format(_dataSelecionada).toUpperCase(); 
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingStatus) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final intervalo = _getIntervaloDatas();
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final bool acessoPermitido = _verificarAcesso(intervalo);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Relatórios", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              acessoPermitido ? Icons.picture_as_pdf : Icons.lock, 
              color: acessoPermitido ? Colors.purple : Colors.grey
            ),
            tooltip: acessoPermitido ? "Exportar PDF" : "Recurso Premium",
            onPressed: _gerarPDF,
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTabButton("Dia"),
                _buildTabButton("Semana"),
                _buildTabButton("Mês"),
              ],
            ),
          ),

          GestureDetector(
            onTap: _escolherData,
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.purple,
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.calendar_month, color: Colors.white),
                  Text(
                    _getTextoData(),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.white),
                ],
              ),
            ),
          ),

          Expanded(
            child: !acessoPermitido 
              ? _buildPremiumLock() 
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('financas')
                      .where('userId', isEqualTo: user?.uid)
                      .where('data', isGreaterThanOrEqualTo: Timestamp.fromDate(intervalo.start))
                      .where('data', isLessThanOrEqualTo: Timestamp.fromDate(intervalo.end))
                      .orderBy('data', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      // Se o erro for de índice, ele mostra aqui
                      return Center(child: Text("Erro: ${snapshot.error}")); 
                    }

                    final docs = snapshot.data?.docs ?? [];

                    double totalFaturamento = 0.0;
                    int qtdCorridas = 0;
                    
                    Map<String, double> resumoApps = {}; 
                    Map<String, double> resumoGastos = {}; 

                    for (var doc in docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      
                      // --- CORREÇÃO DE SEGURANÇA (INT -> DOUBLE) ---
                      // Se for null vira 0, se for int vira double, se for double mantém.
                      final double valor = (data['valor'] ?? 0).toDouble();
                      
                      final String categoria = data['categoria'] ?? 'Outros';
                      
                      if (data['tipo'] == 'Entrada') {
                        totalFaturamento += valor;
                        qtdCorridas++;
                        resumoApps[categoria] = (resumoApps[categoria] ?? 0) + valor;
                      } else {
                        resumoGastos[categoria] = (resumoGastos[categoria] ?? 0) + valor;
                      }
                    }

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildInfoCard(
                                  "Faturamento", 
                                  currencyFormat.format(totalFaturamento), 
                                  Icons.attach_money, 
                                  Colors.green
                                )
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: _buildInfoCard(
                                  "Corridas", 
                                  "$qtdCorridas", 
                                  Icons.local_taxi, 
                                  Colors.orange
                                )
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        Padding(
                          padding: const EdgeInsets.only(left: 20, bottom: 10),
                          child: Align(
                            alignment: Alignment.centerLeft, 
                            child: Text(
                              _filtroSelecionado == 'Dia' ? "Detalhamento" : "Resumo Global por App", 
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)
                            )
                          ),
                        ),

                        Expanded(
                          child: docs.isEmpty 
                            ? const Center(child: Text("Sem dados neste período.", style: TextStyle(color: Colors.grey)))
                            : _filtroSelecionado == 'Dia' 
                                // LISTA DIÁRIA
                                ? ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    itemCount: docs.length,
                                    itemBuilder: (context, index) {
                                      final data = docs[index].data() as Map<String, dynamic>;
                                      final bool isEntrada = data['tipo'] == 'Entrada';
                                      
                                      // --- CORREÇÃO DE SEGURANÇA ---
                                      final double valor = (data['valor'] ?? 0).toDouble();
                                      
                                      final date = (data['data'] as Timestamp).toDate();
                                      
                                      return Card(
                                        margin: const EdgeInsets.only(bottom: 10),
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: isEntrada ? Colors.green[50] : Colors.red[50],
                                            child: Icon(
                                              isEntrada ? Icons.arrow_upward : Icons.arrow_downward,
                                              color: isEntrada ? Colors.green : Colors.red,
                                              size: 18,
                                            ),
                                          ),
                                          title: Text(data['categoria'] ?? 'Geral', style: const TextStyle(fontWeight: FontWeight.bold)),
                                          subtitle: Text(DateFormat('HH:mm').format(date)),
                                          trailing: Text(
                                            currencyFormat.format(valor),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isEntrada ? Colors.green[700] : Colors.red[700]
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                // LISTA AGRUPADA (SEMANAL/MENSAL)
                                : ListView(
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    children: [
                                      ...resumoApps.entries.map((entry) {
                                        return Card(
                                          elevation: 3,
                                          margin: const EdgeInsets.only(bottom: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          child: ListTile(
                                            leading: Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.green[100],
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(Icons.apps, color: Colors.green),
                                            ),
                                            title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            trailing: Text(
                                              currencyFormat.format(entry.value),
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green[800]),
                                            ),
                                          ),
                                        );
                                      }),

                                      if (resumoGastos.isNotEmpty) ...[
                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 15),
                                          child: Text("Resumo de Gastos", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                        ),
                                        ...resumoGastos.entries.map((entry) {
                                          return Card(
                                            color: Colors.red[50],
                                            margin: const EdgeInsets.only(bottom: 10),
                                            child: ListTile(
                                              leading: const Icon(Icons.local_gas_station, color: Colors.red),
                                              title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                                              trailing: Text(
                                                currencyFormat.format(entry.value),
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                                              ),
                                            ),
                                          );
                                        }),
                                      ],
                                    ],
                                  ),
                        ),
                      ],
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumLock() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_clock, size: 80, color: Colors.amber),
            ),
            const SizedBox(height: 25),
            const Text(
              "Histórico Antigo Bloqueado",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            const Text(
              "O plano gratuito permite ver apenas os últimos 30 dias de movimentação. Seja Premium para acessar todo o seu histórico.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (context) => const PremiumScreen())
                ).then((_) => _checkPremiumStatus());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text("SEJA PREMIUM 👑", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String text) {
    final bool isSelected = _filtroSelecionado == text;
    return GestureDetector(
      onTap: () => setState(() => _filtroSelecionado = text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: Colors.grey[300]!),
        ),
        child: Text(text, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}