import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  // Variáveis do Formulário
  final _detalhesController = TextEditingController();
  final _valorController = TextEditingController();

  String _tipoSelecionado = 'Entrada';
  String? _categoriaSelecionada;
  String? _idParaEditar;
  bool _isLoading = false;

  // Variável de Filtro
  String _filtroPeriodo = 'Hoje'; // Opções: Hoje, Semana, Mês

  // Listas de Categorias
  final List<String> _appsEntrada = [
    'Uber',
    '99',
    'Indriver',
    'Particular',
    'Outro',
  ];
  final List<String> _gastosSaida = [
    'Gasolina',
    'GNV',
    'Etanol',
    'Óleo',
    'Manutenção',
    'Alimentação',
    'Outro',
  ];

  // --- LÓGICA DE DATAS (CORRIGIDA) ---
  DateTime _getDataInicio() {
    final now = DateTime.now();
    
    // Zera o horário para 00:00:00 para pegar o dia inteiro
    final hojeZerado = DateTime(now.year, now.month, now.day);

    if (_filtroPeriodo == 'Hoje') {
      return hojeZerado;
    } else if (_filtroPeriodo == 'Semana') {
      // Pega a segunda-feira da semana atual
      final startOfWeek = hojeZerado.subtract(Duration(days: now.weekday - 1));
      return startOfWeek;
    } else {
      // Dia 1 do mês atual
      return DateTime(now.year, now.month, 1);
    }
  }

  // --- FUNÇÕES DE BANCO DE DADOS ---
  Future<void> _salvarMovimentacao() async {
    if (_valorController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha o valor.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        double valor = double.parse(_valorController.text.replaceAll(',', '.'));

        final dados = {
          'userId': user.uid,
          'tipo': _tipoSelecionado,
          'categoria': _categoriaSelecionada ?? 'Geral', // Garante categoria
          'detalhes': _detalhesController.text,
          'valor': valor,
          // Se for edição, NÃO muda a data. Se for novo, usa data do servidor.
          if (_idParaEditar == null) 'data': FieldValue.serverTimestamp(),
        };

        if (_idParaEditar == null) {
          await FirebaseFirestore.instance.collection('financas').add(dados);
        } else {
          await FirebaseFirestore.instance
              .collection('financas')
              .doc(_idParaEditar)
              .update(dados);
        }

        if (!mounted) return;
        Navigator.of(context).pop(); // Fecha o modal
        
        // Limpa campos para próxima vez
        _detalhesController.clear();
        _valorController.clear();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_idParaEditar == null ? 'Salvo!' : 'Atualizado!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _excluirMovimentacao() async {
    if (_idParaEditar == null) return;
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('financas')
          .doc(_idParaEditar)
          .delete();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint("Erro ao excluir: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- FORMULÁRIO (MODAL) ---
  void _abrirFormulario(BuildContext context, {DocumentSnapshot? doc}) {
    if (doc != null) {
      final data = doc.data() as Map<String, dynamic>;
      _idParaEditar = doc.id;
      _tipoSelecionado = data['tipo'];
      _categoriaSelecionada = data['categoria'];
      _detalhesController.text = data['detalhes'] ?? '';
      
      // Conversão segura também aqui ao abrir para edição
      double val = (data['valor'] ?? 0).toDouble();
      _valorController.text = val.toStringAsFixed(2);
    } else {
      _idParaEditar = null;
      _tipoSelecionado = 'Entrada';
      _categoriaSelecionada = null;
      _detalhesController.clear();
      _valorController.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _idParaEditar == null ? 'Nova Movimentação' : 'Editar',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_idParaEditar != null)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: _excluirMovimentacao,
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Entrada'),
                          selected: _tipoSelecionado == 'Entrada',
                          onSelected: (v) => setModalState(() {
                            _tipoSelecionado = 'Entrada';
                            _categoriaSelecionada = null;
                          }),
                          selectedColor: Colors.green[100],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Saída'),
                          selected: _tipoSelecionado == 'Saída',
                          onSelected: (v) => setModalState(() {
                            _tipoSelecionado = 'Saída';
                            _categoriaSelecionada = null;
                          }),
                          selectedColor: Colors.red[100],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: _categoriaSelecionada,
                    hint: const Text("Selecione a Categoria"),
                    decoration: const InputDecoration(
                      labelText: 'Categoria',
                      border: OutlineInputBorder(),
                    ),
                    items: (_tipoSelecionado == 'Entrada'
                            ? _appsEntrada
                            : _gastosSaida)
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) =>
                        setModalState(() => _categoriaSelecionada = v),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _detalhesController,
                    decoration: const InputDecoration(
                      labelText: 'Detalhes (Opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _valorController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Valor',
                      prefixText: 'R\$ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 25),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _salvarMovimentacao,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text(
                            'SALVAR',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final dataInicio = _getDataInicio();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Movimentação', // Nome ajustado conforme pedido anterior
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.amber,
        centerTitle: true,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(context),
        backgroundColor: Colors.amber,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text(
          'Lançar',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // --- BARRA DE FILTROS ---
          Container(
            color: Colors.amber,
            padding: const EdgeInsets.only(bottom: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildFilterButton('Hoje'),
                _buildFilterButton('Semana'),
                _buildFilterButton('Mês'),
              ],
            ),
          ),

          // --- LISTA COM ATUALIZAÇÃO AUTOMÁTICA (StreamBuilder) ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // O StreamBuilder é quem garante que os dados atualizem sozinhos
              stream: FirebaseFirestore.instance
                  .collection('financas')
                  .where('userId', isEqualTo: user?.uid)
                  .where('data', isGreaterThanOrEqualTo: Timestamp.fromDate(dataInicio))
                  .orderBy('data', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                   // Se aparecer erro de índice, ele avisa aqui
                  return Center(child: Text("Erro ao carregar: ${snapshot.error}"));
                }

                final docs = snapshot.data?.docs ?? [];

                // Recalcula o saldo a cada atualização
                double totalEntrada = 0.0;
                double totalSaida = 0.0;
                
                for (var doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  // CORREÇÃO AQUI: Convertendo para double de forma segura
                  final valor = (data['valor'] ?? 0).toDouble();
                  if (data['tipo'] == 'Entrada') {
                    totalEntrada += valor;
                  } else {
                    totalSaida += valor;
                  }
                }
                final saldo = totalEntrada - totalSaida;

                return Column(
                  children: [
                    // CARD DE SALDO
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(30),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            "Saldo ($_filtroPeriodo)",
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            "R\$ ${saldo.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Entradas
                              Column(
                                children: [
                                  const Icon(Icons.arrow_upward, color: Colors.green),
                                  Text(
                                    "R\$ ${totalEntrada.toStringAsFixed(2)}",
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Container(height: 30, width: 1, color: Colors.black12),
                              // Saídas
                              Column(
                                children: [
                                  const Icon(Icons.arrow_downward, color: Colors.red),
                                  Text(
                                    "R\$ ${totalSaida.toStringAsFixed(2)}",
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // LISTA DE ITENS
                    Expanded(
                      child: docs.isEmpty
                          ? Center(
                              child: Text(
                                "Nenhum lançamento em $_filtroPeriodo.",
                                style: const TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(top: 10, bottom: 80),
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final doc = docs[index];
                                final dados = doc.data() as Map<String, dynamic>;
                                final bool isEntrada = dados['tipo'] == 'Entrada';
                                // CORREÇÃO AQUI TAMBÉM
                                final double valor = (dados['valor'] ?? 0).toDouble();
                                final String categoria = dados['categoria'] ?? 'Geral';
                                final String detalhes = dados['detalhes'] ?? '';

                                // Formata Data
                                String dataStr = '';
                                if (dados['data'] != null) {
                                  final dt = (dados['data'] as Timestamp).toDate();
                                  dataStr = DateFormat('dd/MM HH:mm').format(dt);
                                }

                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                                  child: InkWell(
                                    onTap: () => _abrirFormulario(context, doc: doc),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: isEntrada ? Colors.green[50] : Colors.red[50],
                                        child: Icon(
                                          isEntrada ? Icons.arrow_upward : Icons.arrow_downward,
                                          color: isEntrada ? Colors.green : Colors.red,
                                          size: 20,
                                        ),
                                      ),
                                      title: Text(
                                        categoria,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text("$dataStr ${detalhes.isNotEmpty ? '- $detalhes' : ''}"),
                                      trailing: Text(
                                        'R\$ ${valor.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isEntrada ? Colors.green[700] : Colors.red[700],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
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

  // Widget do Botão de Filtro
  Widget _buildFilterButton(String periodo) {
    final bool isSelected = _filtroPeriodo == periodo;
    return GestureDetector(
      onTap: () => setState(() => _filtroPeriodo = periodo),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: Colors.black12),
        ),
        child: Text(
          periodo,
          style: TextStyle(
            color: isSelected ? Colors.amber : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}