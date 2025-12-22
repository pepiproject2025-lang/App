import 'package:flutter/material.dart';

class DiagStart extends StatelessWidget {
  const DiagStart({super.key});

  @override
  Widget build(BuildContext context) {
    final vh = MediaQuery.of(context).size.height;

    return Center(
      child: SingleChildScrollView( // 🔑 스크롤 가능하게 변경
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: vh), // 🔑 큰 화면에서는 꽉 채움
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logo_img.png', width: 300),
              const SizedBox(height: 20),
              Image.asset('assets/dog_cat.png', width: 420),
              const SizedBox(height: 20),
              const Text(
                '우리 아이 눈 건강,\nAI로 간편하게 체크해보세요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400, height: 1.4),
              ),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: SizedBox(
                  width: 300,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 4,
                      shadowColor: const Color(0xFF4A90E2).withOpacity(0.4),
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, '/diag');
                    },
                    child: const Text(
                      '진단 시작하기',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600, // Slightly lighter bold for Jua
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
