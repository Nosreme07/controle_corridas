import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';

class TransactionForm extends StatefulWidget {
  final void Function(String? id, String title, double value, DateTime date, TransactionType type) onSubmit;
  final Transaction? existingTransaction;

  const TransactionForm(this.onSubmit, {super.key, this.existingTransaction});

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  // Controladores de texto
  final _descriptionController = TextEditingController(); // Campo aberto (Corrida ou Título)
  final _valueController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  TransactionType _selectedType = TransactionType.income;

  // --- Listas para os Dropdowns ---
  final List<String> _apps = ['99 Pop', 'Uber', 'Indriver', 'Particular', 'Outro'];
  final List<String> _expenseCategories = ['Gasolina', 'Etanol', 'GNV', 'Óleo', 'Manutenção', 'Lava-jato', 'Alimentação', 'Seguro/IPVA', 'Outros'];

  // Variáveis para guardar a escolha do Dropdown
  String _selectedApp = '99 Pop';
  String _selectedCategory = 'Gasolina';

  @override
  void initState() {
    super.initState();
    
    // Lógica para preencher caso seja EDIÇÃO
    if (widget.existingTransaction != null) {
      final tr = widget.existingTransaction!;
      _valueController.text = tr.value.toString();
      _selectedDate = tr.date;
      _selectedType = tr.type;

      // Tentamos separar o título antigo (ex: "99 Pop - Corrida X")
      // Se não tiver o separador " - ", jogamos tudo na descrição
      if (tr.title.contains(' - ')) {
        final parts = tr.title.split(' - ');
        // A primeira parte tentamos encaixar no dropdown, a segunda no texto
        if (tr.type == TransactionType.income && _apps.contains(parts[0])) {
          _selectedApp = parts[0];
          _descriptionController.text = parts.sublist(1).join(' - ');
        } else if (tr.type == TransactionType.expense && _expenseCategories.contains(parts[0])) {
          _selectedCategory = parts[0];
          _descriptionController.text = parts.sublist(1).join(' - ');
        } else {
           _descriptionController.text = tr.title;
        }
      } else {
        _descriptionController.text = tr.title;
      }
    }
  }

  _submitForm() {
    final description = _descriptionController.text;
    final value = double.tryParse(_valueController.text.replaceAll(',', '.')) ?? 0.0;

    if (value <= 0) {
      return;
    }

    // AQUI É O TRUQUE: Juntamos o Dropdown + Descrição para salvar no Título
    String finalTitle = '';

    if (_selectedType == TransactionType.income) {
      // Se não digitou nada na descrição, salva só o nome do App
      if (description.isEmpty) {
        finalTitle = _selectedApp;
      } else {
        finalTitle = "$_selectedApp - $description";
      }
    } else {
       // Se não digitou nada na descrição, salva só a Categoria
      if (description.isEmpty) {
        finalTitle = _selectedCategory;
      } else {
        finalTitle = "$_selectedCategory - $description";
      }
    }

    widget.onSubmit(
      widget.existingTransaction?.id,
      finalTitle,
      value,
      _selectedDate,
      _selectedType,
    );
  }

  _showDatePicker() {
    showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    ).then((pickedDate) {
      if (pickedDate == null) return;
      setState(() {
        _selectedDate = pickedDate;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. SELEÇÃO DO TIPO (TOPO)
            // É importante ficar no topo para mudar os campos abaixo
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('Entrada (Ganho)'),
                  selected: _selectedType == TransactionType.income,
                  selectedColor: Colors.green[200],
                  onSelected: (val) => setState(() => _selectedType = TransactionType.income),
                ),
                const SizedBox(width: 15),
                ChoiceChip(
                  label: const Text('Saída (Gasto)'),
                  selected: _selectedType == TransactionType.expense,
                  selectedColor: Colors.red[200],
                  onSelected: (val) => setState(() => _selectedType = TransactionType.expense),
                ),
              ],
            ),
            const Divider(),

            // 2. CAMPOS DINÂMICOS (MUDAM CONFORME A ESCOLHA ACIMA)
            if (_selectedType == TransactionType.income) ...[
              // === CAMPOS DE ENTRADA ===
              DropdownButtonFormField<String>(
                value: _selectedApp,
                decoration: const InputDecoration(labelText: 'Aplicativo'),
                items: _apps.map((app) {
                  return DropdownMenuItem(value: app, child: Text(app));
                }).toList(),
                onChanged: (value) => setState(() => _selectedApp = value!),
              ),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Detalhes da Corrida (Opcional)',
                  hintText: 'Ex: Aeroporto, Corrida Longa...',
                ),
              ),
            ] else ...[
              // === CAMPOS DE SAÍDA ===
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: _expenseCategories.map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat));
                }).toList(),
                onChanged: (value) => setState(() => _selectedCategory = value!),
              ),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Título / Detalhes',
                  hintText: 'Ex: Posto Shell, Troca de Filtro...',
                ),
              ),
            ],

            // 3. CAMPOS COMUNS (VALOR E DATA)
            TextField(
              controller: _valueController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Valor (R\$)',
                prefixText: 'R\$ ',
              ),
            ),
            
            SizedBox(
              height: 70,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Data: ${DateFormat('dd/MM/y').format(_selectedDate)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  TextButton(
                    onPressed: _showDatePicker,
                    child: const Text('Mudar Data', style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 10),
            
            // BOTÃO DE SALVAR
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedType == TransactionType.income ? Colors.green : Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  widget.existingTransaction == null ? 'Adicionar Lançamento' : 'Salvar Alteração',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}