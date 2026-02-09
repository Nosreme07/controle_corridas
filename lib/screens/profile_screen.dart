import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  // Controladores de Texto
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _vehicleModelController = TextEditingController();
  final TextEditingController _vehiclePlateController = TextEditingController();
  final TextEditingController _pixKeyController = TextEditingController();

  // Variáveis de Imagem (Base64 String)
  String? _profileImageBase64;
  String? _qrCodeImageBase64;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    // 1. Dados do Firebase Auth
    if (user != null) {
      _nameController.text = user!.displayName ?? '';
      _emailController.text = user!.email ?? '';
    }

    // 2. Dados Locais (SharedPreferences)
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _vehicleModelController.text = prefs.getString('vehicle_model') ?? '';
      _vehiclePlateController.text = prefs.getString('vehicle_plate') ?? '';
      _pixKeyController.text = prefs.getString('pix_key') ?? '';
      
      // Carrega as imagens
      _profileImageBase64 = prefs.getString('profile_image_base64');
      _qrCodeImageBase64 = prefs.getString('qr_code_base64');
    });
  }

  // --- FUNÇÃO PARA PEGAR IMAGEM E COMPRIMIR ---
  Future<void> _pickImage(bool isProfile) async {
    try {
      // imageQuality: 20 garante resolução baixa (poucos dados)
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery, 
        imageQuality: 20, 
        maxWidth: 400, // Limita largura
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
      debugPrint("Erro ao pegar imagem: $e");
    }
  }

  // --- FUNÇÃO PARA ABRIR CNH ---
  Future<void> _openCNH() async {
    // Tenta abrir direto na loja de apps (Android)
    final Uri url = Uri.parse("market://details?id=br.gov.serpro.cnhe");
    // Fallback para web se não abrir a loja
    final Uri webUrl = Uri.parse("https://play.google.com/store/apps/details?id=br.gov.serpro.cnhe");
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Não foi possível abrir a loja de apps.")),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // Atualiza Auth
      if (user != null) {
        await user!.updateDisplayName(_nameController.text.trim());
      }

      // Salva no SharedPreferences (Simulando Banco Local rápido)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('vehicle_model', _vehicleModelController.text.trim());
      await prefs.setString('vehicle_plate', _vehiclePlateController.text.trim().toUpperCase());
      await prefs.setString('pix_key', _pixKeyController.text.trim());
      
      if (_profileImageBase64 != null) {
        await prefs.setString('profile_image_base64', _profileImageBase64!);
      }
      if (_qrCodeImageBase64 != null) {
        await prefs.setString('qr_code_base64', _qrCodeImageBase64!);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dados salvos com sucesso!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _logout() async {
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
              const Text("Toque para alterar foto", style: TextStyle(color: Colors.grey, fontSize: 12)),
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

              // Veículo
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

              // PIX KEY
              TextFormField(
                controller: _pixKeyController,
                decoration: const InputDecoration(labelText: 'Chave Pix (CPF/Email/Tel)', prefixIcon: Icon(Icons.pix, color: Colors.green), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),

              // QR CODE PIX
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

              // BOTÃO CNH DIGITAL
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

              // BOTÃO SALVAR
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
            ],
          ),
        ),
      ),
    );
  }
}