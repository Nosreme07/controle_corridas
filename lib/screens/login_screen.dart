import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controladores do LOGIN
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // Controladores do CADASTRO (Modal)
  final _signupEmailController = TextEditingController();
  final _signupPasswordController = TextEditingController();

  final _auth = FirebaseAuth.instance;
  
  bool _isLoading = false;
  bool _isObscure = true; // Olhinho do Login

  // --- FUNÇÃO DE LOGIN (ENTRAR) ---
  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      String message = "Erro ao entrar";
      if (e.code == 'user-not-found') message = "Usuário não cadastrado.";
      if (e.code == 'wrong-password') message = "Senha incorreta.";
      if (e.code == 'invalid-credential') message = "Email ou senha inválidos.";

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- FUNÇÃO QUE REALIZA O CADASTRO (CHAMADA PELO MODAL) ---
  Future<void> _performRegistration(BuildContext modalContext) async {
    if (_signupEmailController.text.isEmpty || _signupPasswordController.text.length < 6) {
      ScaffoldMessenger.of(modalContext).showSnackBar(
        const SnackBar(content: Text("Email inválido ou senha curta (mín. 6).")),
      );
      return;
    }

    // Fecha o modal antes de carregar
    Navigator.pop(modalContext);
    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _signupEmailController.text.trim(),
        password: _signupPasswordController.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection('usuarios') // Coleção antiga, mas ok manter se já tem dados
          .doc(userCredential.user!.uid)
          .set({
            'email': _signupEmailController.text.trim(),
            'data_cadastro': DateTime.now(),
            'saldo_geral': 0.0,
            'nome': 'Novo Motorista',
            'isPremium': false, 
          });

      // Salva na coleção 'users' (nova) também para garantir compatibilidade futura
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'email': _signupEmailController.text.trim(),
          'isPremium': false,
      }, SetOptions(merge: true));

      if (!mounted) return;

      // Vai para a Home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
      
    } on FirebaseAuthException catch (e) {
      String message = "Erro ao cadastrar";
      if (e.code == 'email-already-in-use') message = "Este e-mail já existe.";
      if (e.code == 'weak-password') message = "A senha é muito fraca.";

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ABRIR MODAL DE CADASTRO ---
  void _openSignUpModal() {
    _signupEmailController.clear();
    _signupPasswordController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool isModalObscure = true;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20, left: 20, right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Criar Nova Conta",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  
                  TextField(
                    controller: _signupEmailController,
                    decoration: const InputDecoration(
                      labelText: 'Seu E-mail',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 15),

                  TextField(
                    controller: _signupPasswordController,
                    obscureText: isModalObscure,
                    decoration: InputDecoration(
                      labelText: 'Crie uma Senha',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(isModalObscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () {
                          setModalState(() {
                            isModalObscure = !isModalObscure;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => _performRegistration(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        "CADASTRAR E ENTRAR",
                        style: TextStyle(fontWeight: FontWeight.bold),
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

  // Função Esqueci Senha
  Future<void> _resetPassword() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Digite seu e-mail no campo de login primeiro.")),
      );
      return;
    }
    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email de recuperação enviado!"), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erro ao enviar email."), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Image.asset('assets/images/domex_logo.png', height: 120),
              const SizedBox(height: 40),

              // LOGIN: Email
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // LOGIN: Senha
              TextField(
                controller: _passwordController,
                obscureText: _isObscure,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_isObscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _isObscure = !_isObscure),
                  ),
                ),
              ),
              
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _resetPassword,
                  child: const Text("Esqueci minha senha", style: TextStyle(color: Colors.grey)),
                ),
              ),

              const SizedBox(height: 20),

              _isLoading
                  ? const CircularProgressIndicator()
                  : Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _signIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                            ),
                            child: const Text(
                              'ENTRAR',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        
                        // BOTÃO QUE ABRE O MODAL
                        TextButton(
                          onPressed: _openSignUpModal, 
                          child: const Text.rich(
                            TextSpan(
                              text: "Não tem conta? ",
                              style: TextStyle(color: Colors.black54),
                              children: [
                                TextSpan(
                                  text: "Cadastre-se aqui",
                                  style: TextStyle(
                                    color: Colors.blue, 
                                    fontWeight: FontWeight.bold
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

              // --- CRÉDITOS DO DESENVOLVEDOR ---
              const SizedBox(height: 60),
              const Text(
                "Desenvolvido por Emerson Fernandes",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



