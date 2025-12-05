import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'diag_start_page.dart'; // '/start'에서 사용할 페이지
import 'dart:typed_data';

const String kDummyMarkdown = '''
# ERROR: No Data
## 진단 결과 데이터를 불러올 수 없습니다.
''';
class DiagResult extends StatelessWidget {
  const DiagResult({super.key});

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF4A90E2);
    final Color cardColor = Colors.white;
    final Color warningColor = const Color(0xFFFFF3E0);
    final TextTheme textTheme = Theme.of(context).textTheme;

    final args = ModalRoute.of(context)?.settings.arguments;
    String markdown = kDummyMarkdown;
    String petName = "나이 미입력";
    Uint8List? imageBytes;

    if (args is Map){
      final argMd = args['markdown'] as String?;
      if (argMd != null) {
        markdown = argMd;
      }
      final argName = args['name'] as String?;
      if (argName != null) {
        petName = argName;
      }
      final argImageBytes = args['imageBytes'] as Uint8List?;
      if (argImageBytes != null) {
        imageBytes = argImageBytes;
      }
    } else if (args is String) {
      markdown = args;
    }

    // 진단 정보 추출
    Map<String, dynamic>? diagnosisData;
    String? caseId;
    if (args is Map) {
      if (args['diagnosis'] != null) {
        diagnosisData = args['diagnosis'] as Map<String, dynamic>;
      }
      if (args['case_id'] != null) {
        caseId = args['case_id'] as String;
      }
    }


    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔹 상단 홈 아이콘
                Row(
                  children: [
                    // 왼쪽 홈 아이콘
                    IconButton(
                      icon: const Icon(Icons.home_outlined, color: Colors.black87, size: 27),
                      splashRadius: 22,
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/start',
                              (route) => false,
                        );
                      },
                    ),

                    // 가운데 로고
                    Expanded(
                      child: Center(
                        child: Image.asset(
                          'assets/logo_img.png',
                          height: 20,
                        ),
                      ),
                    ),

                    // 오른쪽 공간 확보 (아이콘과 균형 맞추기)
                    const SizedBox(width: 48), // IconButton 크기만큼 맞춰줌
                  ],
                ),

                const SizedBox(height: 16),

                // 제목
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Text(
                    'Diagnosis Result',
                    style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),

                _buildWarningCard(warningColor),
                const SizedBox(height: 24),

                _buildResultSummaryCard(
                  cardColor, 
                  primaryColor, 
                  textTheme,
                  petName,
                  imageBytes,
                ),
                const SizedBox(height: 24),

                if (diagnosisData != null) ...[
                  _buildDiagnosisCard(cardColor, primaryColor, textTheme, diagnosisData),
                  const SizedBox(height: 24),
                ],

                _buildDetailsCard(cardColor, textTheme, markdown),
                const SizedBox(height: 32),

                _buildActionButtons(context, caseId, imageBytes),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWarningCard(Color warningColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: warningColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'AI의 진단은 참고용이며, 정확하지 않을 수 있습니다.',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                SizedBox(height: 2),
                Text(
                  '정확한 진단은 반드시 수의사와 상담하세요.',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSummaryCard(Color cardColor, Color primaryColor, TextTheme textTheme, String petName, Uint8List? imageBytes) {
    return Card(
      elevation: 2,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: imageBytes != null
                ? Image.memory(
                    imageBytes,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: double.infinity,
                    height: 200,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image_not_supported, size: 80, color: Colors.white70),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoText(textTheme, '이름', petName),
                // const SizedBox(height: 8),
                // _buildInfoText(textTheme, '나이', '3살'),
                // const SizedBox(height: 8),
                // _buildInfoText(textTheme, '사용자', 'aaaa@gmail.com'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoText(TextTheme textTheme, String title, String value) {
    return Text.rich(
      TextSpan(
        style: textTheme.bodyMedium?.copyWith(fontSize: 15),
        children: [
          TextSpan(
            text: '$title: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(Color cardColor, TextTheme textTheme, String markdown) {
    return Card(
      elevation: 2,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: MarkdownBody(
          styleSheet: MarkdownStyleSheet(
            h1: GoogleFonts.notoSansKr(
              textStyle: textTheme.titleLarge,
              fontWeight: FontWeight.bold,
            ),
            h2: GoogleFonts.notoSansKr(
              textStyle: textTheme.titleMedium,
              fontWeight: FontWeight.bold,
            ),
            p: GoogleFonts.notoSansKr(
              textStyle: textTheme.bodyMedium,
              height: 1.5,
            ),
            listBullet: GoogleFonts.notoSansKr(
              textStyle: textTheme.bodyMedium,
            ),
          ),
          data: markdown,
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, String? caseId, Uint8List? imageBytes) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: 12),
              elevation: 3,
              shadowColor: const Color(0xFF4A90E2).withOpacity(0.4),
            ),
            onPressed: () {
              Navigator.pushNamed(
                context, 
                '/chatbot',
                arguments: {
                  'case_id': caseId,
                  'imageBytes': imageBytes, // 이미지 전달
                },
              );
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.chat_bubble_outline_rounded, size: 24),
                SizedBox(height: 4),
                Text('AI 상담', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2A5A9E),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onPressed: () {},
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.medical_services, size: 24),
                SizedBox(height: 4),
                Text('수의사와 상담하기', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A99A8),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onPressed: () {},
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.location_on, size: 24),
                SizedBox(height: 4),
                Text('동물병원 찾기', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildDiagnosisCard(Color cardColor, Color primaryColor, TextTheme textTheme, Map<String, dynamic> diagnosisData) {
    final String diagnosisName = diagnosisData['diagnosis'] ?? '진단명 없음';
    final List<dynamic> symptoms = diagnosisData['symptoms'] ?? [];

    return Card(
      elevation: 2,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.health_and_safety, color: primaryColor, size: 28),
                const SizedBox(width: 10),
                Text(
                  'AI 진단 결과',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryColor.withOpacity(0.3)),
              ),
              child: Text(
                diagnosisName,
                style: GoogleFonts.notoSansKr(
                  textStyle: textTheme.headlineSmall,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (symptoms.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                '주요 증상',
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...symptoms.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        s.toString(),
                        style: GoogleFonts.notoSansKr(height: 1.4),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }
}
