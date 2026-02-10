import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para copiar o Pix
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  // SEU CÓDIGO PIX COPIA E COLA
  final String _pixCode = "00020101021126880014br.gov.bcb.pix01361bf6ae89-a8cd-45da-bf4f-1dbf28a9b7320226Domex  controle financeiro520400005303986540519.995802BR5920EMERSON F DOS SANTOS6006MORENO62070503***63044E0E";
  
  // SEU LINK DO WHATSAPP
  final String _linkWhatsApp = "https://wa.me/5581999999999?text=Olá, fiz o Pix de R\$ 19,99 para o Domex Premium. Segue o comprovante:";

  // Função para Copiar o Pix
  void _copiarPix() {
    Clipboard.setData(ClipboardData(text: _pixCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Código Pix copiado! Abra seu banco e cole."),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Função para abrir o WhatsApp
  Future<void> _abrirWhatsApp() async {
    final Uri urlZap = Uri.parse(_linkWhatsApp);
    try {
      await launchUrl(urlZap, mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Não foi possível abrir o WhatsApp.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Efeito de fundo
          Positioned(
            top: -50, right: -50,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.2), blurRadius: 100)],
              ),
            ),
          ),
          
          SingleChildScrollView(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.workspace_premium, size: 80, color: Colors.amber),
                const SizedBox(height: 20),
                const Text(
                  "DOMEX PREMIUM",
                  style: TextStyle(color: Colors.amber, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Desbloqueie todo o potencial do seu controle financeiro.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 30),
                
                _buildBenefit("Monitor Automático de Corridas"),
                _buildBenefit("Histórico Financeiro Completo"),
                _buildBenefit("Exportação de Relatórios PDF"),
                _buildBenefit("Sem Mensalidade (Vitalício)"),
                
                const SizedBox(height: 30),
                
                // CARD DE PREÇO
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.amber.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(15),
                    color: Colors.amber.withOpacity(0.05),
                  ),
                  child: const Column(
                    children: [
                      Text("OFERTA ÚNICA", style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                      SizedBox(height: 5),
                      Text("R\$ 19,99", style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                      Text("Pagamento via Pix", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // BOTÃO COPIAR PIX
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: _copiarPix,
                    icon: const Icon(Icons.copy),
                    label: const Text("COPIAR CÓDIGO PIX", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                
                const SizedBox(height: 15),

                // BOTÃO WHATSAPP
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.green),
                      foregroundColor: Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: _abrirWhatsApp,
                    icon: const Icon(Icons.chat),
                    label: const Text("ENVIAR COMPROVANTE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                const Text(
                  "Ao enviar o comprovante, liberamos seu acesso imediatamente.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white30, fontSize: 12),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefit(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
          const SizedBox(width: 15),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 15))),
        ],
      ),
    );
  }
}