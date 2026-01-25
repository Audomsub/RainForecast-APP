import 'package:flutter/material.dart';
import 'package:rainforecast_app/src/service/db_service.dart';
// ตรวจสอบ path นี้ว่าถูกต้องหรือไม่
import 'package:rainforecast_app/src/admin/addminpage.dart'; 

class AdminLoginOverlay extends StatefulWidget {
  const AdminLoginOverlay({super.key});

  @override
  State<AdminLoginOverlay> createState() => _AdminLoginOverlayState();
}

class _AdminLoginOverlayState extends State<AdminLoginOverlay> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final DBService dbService = DBService();

  bool isLoading = false;
  String message = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        message = '❗ กรุณากรอก Email และ Password';
      });
      return;
    }

    setState(() {
      isLoading = true;
      message = '';
    });

    final success = await dbService.loginAdmin(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      setState(() => isLoading = false);
      // ปิด Overlay ก่อนแล้วค่อยไปหน้า Dashboard หรือจะ pushReplacement ก็ได้
      Navigator.pop(context); 
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AdminDashboardPage(),
        ),
      );
    } else {
      setState(() {
        isLoading = false;
        message = '❌ Email หรือ Password ไม่ถูกต้อง';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 320,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.65),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 30),
              const Icon(
                Icons.admin_panel_settings,
                size: 80,
                color: Colors.white,
              ),
              const SizedBox(height: 10),
              const Text(
                'Admin Management',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _inputField(
                'Email',
                controller: _emailController,
              ),
              const SizedBox(height: 12),
              _inputField(
                'Password',
                controller: _passwordController,
                isPassword: true,
              ),
              const SizedBox(height: 10),
              if (message.isNotEmpty)
                Text(
                  message,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  onPressed: isLoading ? null : login,
                  child: isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        )
                      : const Text(
                          'Sign In',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
        // 🔙 ปุ่มย้อนกลับ
        Positioned(
          top: 5,
          left: 5,
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            color: Colors.white,
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ],
    );
  }

  Widget _inputField(
    String hint, {
    required TextEditingController controller,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}