import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
// NOVOS IMPORTS PARA O PDF
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/transaction.dart';
import '../components/transaction_form.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Transaction> _transactions = [];
  DateTime _selectedDate = DateTime.now();
  
  // Variáveis para o Controle de Km
  double? _startKm;
  double? _endKm;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _loadDailyMileage();
  }

  // --- PERSISTÊNCIA ---
  Future<void> _saveTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(_transactions.map((tr) => tr.toJson()).toList());
    await prefs.setString('transactions_data', data);
    setState(() {}); 
  }

  Future<void> _loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('transactions_data');
    if (data != null) {
      final List<dynamic> decodedList = jsonDecode(data);
      setState(() {
        _transactions = decodedList.map((item) => Transaction.fromJson(item)).toList();
        _transactions.sort((a, b) => b.date.compareTo(a.date));
      });
    }
  }

  String get _todayKey => DateFormat('yyyyMMdd').format(DateTime.now());

  Future<void> _loadDailyMileage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _startKm = prefs.getDouble('km_start_$_todayKey');
      _endKm = prefs.getDouble('km_end_$_todayKey');
    });
  }

  Future<void> _setMileage(bool isStart, double value) async {
    final prefs = await SharedPreferences.getInstance();
    final type = isStart ? 'km_start' : 'km_end';
    await prefs.setDouble('${type}_$_todayKey', value);
    _loadDailyMileage();
  }

  // --- LÓGICA DO PDF (NOVO) ---
  Future<void> _generatePdf() async {
    final pdf = pw.Document();
    
    // Filtra dados do mês
    final monthTransactions = _monthlyTransactions;
    final totalIncome = monthTransactions.where((t) => t.type == TransactionType.income).fold(0.0, (s, t) => s + t.value);
    final totalExpense = monthTransactions.where((t) => t.type == TransactionType.expense).fold(0.0, (s, t) => s + t.value);
    final balance = totalIncome - totalExpense;
    final monthName = DateFormat('MMMM y', 'pt_BR').format(_selectedDate).toUpperCase();

    // Carrega uma fonte que aceita acentos (Opcional, mas recomendado)
    final font = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Cabeçalho
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Relatório de Corridas', style: pw.TextStyle(font: fontBold, fontSize: 20)),
                    pw.Text(monthName, style: pw.TextStyle(font: font, fontSize: 16)),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 20),

              // Resumo Financeiro
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Column(children: [
                      pw.Text('Entradas', style: pw.TextStyle(font: font)),
                      pw.Text('R\$ ${totalIncome.toStringAsFixed(2)}', style: pw.TextStyle(font: fontBold, color: PdfColors.green)),
                    ]),
                    pw.Column(children: [
                      pw.Text('Saídas', style: pw.TextStyle(font: font)),
                      pw.Text('R\$ ${totalExpense.toStringAsFixed(2)}', style: pw.TextStyle(font: fontBold, color: PdfColors.red)),
                    ]),
                    pw.Column(children: [
                      pw.Text('Saldo', style: pw.TextStyle(font: font)),
                      pw.Text('R\$ ${balance.toStringAsFixed(2)}', style: pw.TextStyle(font: fontBold, fontSize: 14)),
                    ]),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Tabela de Dados
              pw.Table.fromTextArray(
                context: context,
                border: null,
                headerStyle: pw.TextStyle(font: fontBold),
                cellStyle: pw.TextStyle(font: font, fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                headers: ['Data', 'Descrição', 'Tipo', 'Valor'],
                data: monthTransactions.map((tr) {
                  return [
                    DateFormat('dd/MM').format(tr.date),
                    tr.title,
                    tr.type == TransactionType.income ? 'Entrada' : 'Saída',
                    'R\$ ${tr.value.toStringAsFixed(2)}',
                  ];
                }).toList(),
              ),
            ],
          );
        },
      ),
    );

    // Abre a pré-visualização nativa do celular (com botão de compartilhar)
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Relatorio_$monthName',
    );
  }

  // --- HELPERS E UI ---

  void _showMileageDialog(bool isStart) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isStart ? 'Km Inicial' : 'Km Final'),
        content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Digite a Km')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null) {
                _setMileage(isStart, val);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  List<Transaction> get _monthlyTransactions {
    return _transactions.where((tr) {
      return tr.date.month == _selectedDate.month && 
             tr.date.year == _selectedDate.year;
    }).toList();
  }

  double get _monthlyBalance => _calculateBalance(_monthlyTransactions);

  List<Transaction> get _todayTransactions {
    final now = DateTime.now();
    return _transactions.where((tr) => tr.date.day == now.day && tr.date.month == now.month && tr.date.year == now.year).toList();
  }

  double get _todayProfit => _calculateBalance(_todayTransactions);

  double _calculateBalance(List<Transaction> trs) {
    double income = trs.where((t) => t.type == TransactionType.income).fold(0.0, (s, t) => s + t.value);
    double expense = trs.where((t) => t.type == TransactionType.expense).fold(0.0, (s, t) => s + t.value);
    return income - expense;
  }

  void _addOrEditTransaction(String? id, String title, double value, DateTime date, TransactionType type) {
    if (id == null) {
      setState(() => _transactions.add(Transaction(id: const Uuid().v4(), title: title, value: value, date: date, type: type)));
    } else {
      final index = _transactions.indexWhere((tr) => tr.id == id);
      if (index >= 0) {
        setState(() => _transactions[index] = Transaction(id: id, title: title, value: value, date: date, type: type));
      }
    }
    setState(() => _transactions.sort((a, b) => b.date.compareTo(a.date)));
    _saveTransactions();
    Navigator.of(context).pop();
  }

  void _deleteTransaction(String id) {
    setState(() => _transactions.removeWhere((tr) => tr.id == id));
    _saveTransactions();
  }

  void _openTransactionFormModal(BuildContext context, {Transaction? transaction}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: TransactionForm(_addOrEditTransaction, existingTransaction: transaction),
      ),
    );
  }

  void _previousMonth() => setState(() => _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1));
  void _nextMonth() => setState(() => _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1));

  // WIDGET CARD KM (CÓDIGO ANTERIOR)
  Widget _buildMileageCard() {
    double kmRodados = 0;
    double rendimentoPorKm = 0;
    if (_startKm != null && _endKm != null) {
      kmRodados = _endKm! - _startKm!;
      if (kmRodados > 0) rendimentoPorKm = _todayProfit / kmRodados;
    }

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            const Text("RESUMO DE HOJE", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(onTap: () => _showMileageDialog(true), child: Column(children: [const Text('Km Inicial', style: TextStyle(color: Colors.white70)), Text(_startKm?.toInt().toString() ?? '---', style: const TextStyle(color: Colors.white, fontSize: 18))])),
                const Icon(Icons.arrow_forward, color: Colors.white24),
                GestureDetector(onTap: () => _showMileageDialog(false), child: Column(children: [const Text('Km Final', style: TextStyle(color: Colors.white70)), Text(_endKm?.toInt().toString() ?? '---', style: const TextStyle(color: Colors.white, fontSize: 18))])),
              ],
            ),
            const Divider(color: Colors.white24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                 Column(children: [const Text('Rodou', style: TextStyle(color: Colors.white70)), Text('${kmRodados.toInt()} km', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
                 Column(children: [const Text('Lucro', style: TextStyle(color: Colors.white70)), Text('R\$ ${_todayProfit.toStringAsFixed(2)}', style: TextStyle(color: _todayProfit >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold))]),
                 Column(children: [const Text('R\$/Km', style: TextStyle(color: Colors.white70)), Text('R\$ ${rendimentoPorKm.toStringAsFixed(2)}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold))]),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayedTransactions = _monthlyTransactions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Controle de Corridas'),
        actions: [
          // BOTÃO DE PDF AQUI
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Gerar Relatório',
            onPressed: displayedTransactions.isEmpty 
              ? null // Desabilita se não tiver dados
              : _generatePdf, 
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openTransactionFormModal(context),
          )
        ],
      ),
      body: Column(
        children: [
          _buildMileageCard(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: const Icon(Icons.arrow_back_ios, size: 16), onPressed: _previousMonth),
                Text(DateFormat('MMMM y', 'pt_BR').format(_selectedDate).toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.arrow_forward_ios, size: 16), onPressed: _nextMonth),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Saldo do Mês:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('R\$ ${_monthlyBalance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: displayedTransactions.length,
              itemBuilder: (ctx, index) {
                final tr = displayedTransactions[index];
                return Dismissible(
                  key: ValueKey(tr.id),
                  background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                  onDismissed: (_) => _deleteTransaction(tr.id),
                  child: Card(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 15),
                    child: InkWell(
                      onTap: () => _openTransactionFormModal(context, transaction: tr),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: tr.type == TransactionType.income ? Colors.green[100] : Colors.red[100],
                          child: Icon(tr.type == TransactionType.income ? Icons.arrow_upward : Icons.arrow_downward, color: tr.type == TransactionType.income ? Colors.green : Colors.red, size: 16),
                        ),
                        title: Text(tr.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(DateFormat('dd/MM HH:mm').format(tr.date)),
                        trailing: Text('R\$ ${tr.value.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: tr.type == TransactionType.income ? Colors.green[800] : Colors.red[800])),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        child: const Icon(Icons.add, color: Colors.amber),
        onPressed: () => _openTransactionFormModal(context),
      ),
    );
  }
}