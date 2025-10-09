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
                '반려동물 케어',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: SizedBox(
                  width: 300,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF4A90E2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      debugPrint('시작하기 버튼 눌림');
                      Navigator.pushNamed(context, '/diag');  // 프레임 위에서 라우트만 변경
                    },
                    child: const Text(
                      '시작하기',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
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
