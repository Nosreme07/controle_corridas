enum TransactionType { income, expense }

class Transaction {
  final String id;
  final String title;
  final double value;
  final DateTime date;
  final TransactionType type;

  Transaction({
    required this.id,
    required this.title,
    required this.value,
    required this.date,
    required this.type,
  });

  // Transforma os dados em Mapa (para salvar)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'value': value,
      'date': date.toIso8601String(), // Datas viram texto
      'type': type.index, // Enum vira número (0 ou 1)
    };
  }

  // Cria a Transação a partir do Mapa (para carregar)
  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      title: json['title'],
      value: json['value'],
      date: DateTime.parse(json['date']),
      type: TransactionType.values[json['type']],
    );
  }
}