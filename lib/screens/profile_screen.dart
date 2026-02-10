import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login_screen.dart';
import 'premium_screen.dart'; 

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  // Controladores
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _vehicleModelController = TextEditingController();
  final TextEditingController _vehiclePlateController = TextEditingController();
  final TextEditingController _pixKeyController = TextEditingController();

  String? _profileImageBase64;
  String? _qrCodeImageBase64;
  bool _isLoading = false;
  
  // Status Premium
  bool isPremium = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkPremiumStatus();
  }

  // --- LÓGICA DE VERIFICAÇÃO PREMIUM ---
  Future<void> _checkPremiumStatus() async {
    if (user != null) {
      // 1. REGRA MÁGICA: Seu email é sempre Premium
      if (user!.email == 'emerson.fernandesantos@gmail.com') {
        if (mounted) setState(() => isPremium = true);
        return; 
      }

      // 2. Verifica no Banco de Dados para outros usuários
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
        if (doc.exists && doc.data() != null) {
          if (mounted) {
            setState(() {
              isPremium = doc.data()!['isPremium'] == true;
            });
          }
        }
      } catch (e) {
        debugPrint("Erro ao checar premium: $e");
      }
    }
  }

  Future<void> _loadUserData() async {
    if (user != null) {
      _nameController.text = user!.displayName ?? '';
      _emailController.text = user!.email ?? '';
    }

    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _vehicleModelController.text = prefs.getString('vehicle_model') ?? '';
      _vehiclePlateController.text = prefs.getString('vehicle_plate') ?? '';
      _pixKeyController.text = prefs.getString('pix_key') ?? '';
      _profileImageBase64 = prefs.getString('profile_image_base64');
      _qrCodeImageBase64 = prefs.getString('qr_code_base64');
    });
  }

  Future<void> _pickImage(bool isProfile) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery, 
        imageQuality: 20, 
        maxWidth: 400, 
      );
      
      if (image != null) {
        final bytes = await File(image.path).readAsBytes();
        final String base64String = base64Encode(bytes);

        setState(() {
          if (isProfile) {
            _profileImageBase64 = base64String;
          } else {
            _qrCodeImageBase64 = base64String;
          }
        });
      }
    } catch (e) {
      debugPrint("Erro: $e");
    }
  }

  Future<void> _openCNH() async {
    final Uri url = Uri.parse("market://details?id=br.gov.serpro.cnhe");
    final Uri webUrl = Uri.parse("https://play.google.com/store/apps/details?id=br.gov.serpro.cnhe");
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro ao abrir loja.")));
    }
  }

  Future<void> _contactDeveloper() async {
    // Link do WhatsApp
    final Uri url = Uri.parse("https://wa.me/5581999999999?text=Olá, tenho interesse no Domex Premium.");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
       if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Não foi possível abrir o WhatsApp")));
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (user != null) {
        await user!.updateDisplayName(_nameController.text.trim());
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('vehicle_model', _vehicleModelController.text.trim());
      await prefs.setString('vehicle_plate', _vehiclePlateController.text.trim().toUpperCase());
      await prefs.setString('pix_key', _pixKeyController.text.trim());
      
      if (_profileImageBase64 != null) await prefs.setString('profile_image_base64', _profileImageBase64!);
      if (_qrCodeImageBase64 != null) await prefs.setString('qr_code_base64', _qrCodeImageBase64!);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dados salvos com sucesso!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- LOGOUT COM LIMPEZA DE DADOS LOCAIS ---
  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Limpa foto e dados locais para evitar conflito entre contas
    
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Meu Perfil"),
        backgroundColor: Colors.amber,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // --- FOTO DE PERFIL ---
              GestureDetector(
                onTap: () => _pickImage(true),
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: _profileImageBase64 != null
                          ? MemoryImage(base64Decode(_profileImageBase64!))
                          : null,
                      child: _profileImageBase64 == null
                          ? const Icon(Icons.person, size: 60, color: Colors.grey)
                          : null,
                    ),
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.amber,
                      child: Icon(Icons.camera_alt, size: 18, color: Colors.black),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              
              // --- SEÇÃO PREMIUM ---
              _buildPremiumSection(),
              
              const SizedBox(height: 20),

              // Campos Básicos
              TextFormField(
                controller: _emailController,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.email), border: OutlineInputBorder(), filled: true, fillColor: Colors.white70),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nome do Motorista', prefixIcon: Icon(Icons.badge), border: OutlineInputBorder()),
              ),
              
              const SizedBox(height: 25),
              const Divider(),
              const Text("Veículo & Pagamentos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
              const SizedBox(height: 15),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _vehicleModelController,
                      decoration: const InputDecoration(labelText: 'Modelo', prefixIcon: Icon(Icons.directions_car), border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _vehiclePlateController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Placa', prefixIcon: Icon(Icons.confirmation_number), border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _pixKeyController,
                decoration: const InputDecoration(labelText: 'Chave Pix (CPF/Email/Tel)', prefixIcon: Icon(Icons.pix, color: Colors.green), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),

              GestureDetector(
                onTap: () => _pickImage(false),
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.grey[100],
                  ),
                  child: _qrCodeImageBase64 != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(base64Decode(_qrCodeImageBase64!), fit: BoxFit.cover),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_2, size: 50, color: Colors.grey),
                            Text("Toque para adicionar QR Code Pix"),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _openCNH,
                  icon: const Icon(Icons.card_membership, color: Colors.blue),
                  label: const Text("ABRIR CNH DIGITAL", style: TextStyle(fontSize: 16, color: Colors.blue)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.blue)),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("SALVAR ALTERAÇÕES", style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
              
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text("Sair da Conta", style: TextStyle(color: Colors.red)),
              ),

              // --- CRÉDITOS DO DESENVOLVEDOR ---
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.code, size: 16, color: Colors.grey),
                  SizedBox(width: 8),
                  Text(
                    "Desenvolvido\npor Emerson Fernandes",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w500
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // WIDGET DO CARD PREMIUM
  Widget _buildPremiumSection() {
    if (isPremium) {
      // VISÃO DO USUÁRIO PREMIUM
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Colors.amber, Colors.orange]),
          borderRadius: BorderRadius.circular(15),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
        ),
        child: Row(
          children: [
            const Icon(Icons.verified, color: Colors.white, size: 40),
            const SizedBox(width: 15),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("MEMBRO PREMIUM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  Text("Acesso vitalício liberado 👑", style: TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.support_agent, color: Colors.white),
              onPressed: _contactDeveloper,
              tooltip: "Falar com Suporte",
            )
          ],
        ),
      );
    } else {
      // VISÃO DO USUÁRIO GRÁTIS
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.amber, width: 1),
        ),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.star, color: Colors.amber),
                SizedBox(width: 10),
                Text("Seja Premium", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              "Desbloqueie relatórios completos, monitor automático e exportação de PDF.",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const PremiumScreen())).then((_) => _checkPremiumStatus());
                    },
                    child: const Text("COMPRAR - R\$ 19,99", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _contactDeveloper, 
                  icon: const Icon(Icons.chat, color: Colors.green), 
                  tooltip: "Falar com Desenvolvedor",
                )
              ],
            )
          ],
        ),
      );
    }
  }
}