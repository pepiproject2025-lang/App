import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:typed_data';

const String kDummyMarkdown = '''
# 분석 대기 중
데이터를 불러오는 중이거나 분석 결과가 없습니다.
''';

class DiagResult extends StatelessWidget {
  const DiagResult({super.key});

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF4A90E2);
    final Color cardColor = Colors.white;
    // final Color warningColor = const Color(0xFFFFF3E0); // 경고문구 색상
    final TextTheme textTheme = Theme.of(context).textTheme;

    final args = ModalRoute.of(context)?.settings.arguments;
    
    // 데이터 변수 초기화
    String markdown = kDummyMarkdown;
    String petName = "이름 미입력";
    Uint8List? imageBytes;
    String? caseId;
    
    // 🔹 진단명과 증상 파싱을 위한 변수
    String? diagnosisTitle;
    List<String> symptomsList = [];

    if (args is Map) {
      final argMd = args['markdown'] as String?;
      if (argMd != null && argMd.isNotEmpty) {
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
      final argCaseId = args['caseId'] as String?;
      if (argCaseId != null) {
        caseId = argCaseId;
      }
      
      // 🔹 진단 결과 객체(JSON) 파싱
      final diagData = args['diagnosis'];
      if (diagData is Map) {
        diagnosisTitle = diagData['diagnosis']?.toString();
        if (diagData['symptoms'] is List) {
          symptomsList = (diagData['symptoms'] as List)
              .map((e) => e.toString())
              .toList();
        }
      }
    } else if (args is String) {
      markdown = args;
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
                // 1. 상단 네비게이션 (홈 아이콘)
                _buildTopBar(context, caseId, diagData: args is Map ? args['diagnosis'] : null),

                const SizedBox(height: 16),
                
                // ⚠️ 주의사항 (Disclaimer)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0), // Orange/Yellow tint
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFE0B2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange[800], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'AI 진단 결과는 참고용입니다.\n정확한 진단은 반드시 동물병원에 방문하세요.',
                          style: TextStyle(fontSize: 13, color: Colors.orange[900], fontWeight: FontWeight.w500, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 2. 이미지 & 이름 카드
                _buildProfileCard(
                  cardColor,
                  textTheme,
                  petName,
                  caseId,
                  imageBytes,
                ),
                
                const SizedBox(height: 16),

                // 3. [핵심] 진단명 & 증상 요약 카드 (새로 추가된 부분)
                if (diagnosisTitle != null) 
                  _buildDiagnosisSummaryCard(context, cardColor, textTheme, diagnosisTitle, symptomsList),

                // 진단명이 없는 경우(에러 등)에는 표시 안 함
                if (diagnosisTitle != null)
                  const SizedBox(height: 16),

                // 4. 진단 보고서 (마크다운)
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    '상세 리포트',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54),
                  ),
                ),
                _buildDetailsCard(cardColor, textTheme, markdown),
                
                const SizedBox(height: 32),

                // 5. 하단 액션 버튼들
                _buildActionButtons(context, caseId),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 상단 네비게이션 바
  Widget _buildTopBar(BuildContext context, String? caseId, {dynamic diagData}) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.home_outlined, color: Colors.black87, size: 28),
          splashRadius: 22,
          onPressed: () {
            // 홈으로 갈 때 현재 진단 데이터를 넘겨줄지 여부 결정
            if (caseId == null) {
              Navigator.popUntil(context, ModalRoute.withName('/start'));
            } else {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/start',
                (route) => false,
                arguments: {
                  'caseId': caseId,
                  'diagnosis': diagData,
                },
              );
            }
          },
        ),
        Expanded(
          child: Center(
            child: Image.asset(
              'assets/logo_img.png',
              height: 20,
            ),
          ),
        ),
        const SizedBox(width: 48), // 아이콘 균형 맞추기
      ],
    );
  }

  // 1번 영역: 사진 + 이름 + CaseID
  Widget _buildProfileCard(Color cardColor, TextTheme textTheme, String petName, String? caseId, Uint8List? imageBytes) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 이미지 영역
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: imageBytes != null
                ? Image.memory(
                    imageBytes,
                    width: double.infinity,
                    height: 240,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: double.infinity,
                    height: 240,
                    color: Colors.grey[100],
                    child: Icon(Icons.pets, size: 60, color: Colors.grey[300]),
                  ),
          ),
          
          // 텍스트 영역
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '반려동물 이름',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                Text(
                  petName,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontSize: 26,
                  ),
                ),
                if (caseId != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Case ID: $caseId',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500], fontFamily: 'monospace'),
                    ),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2번 영역: 진단명 + 증상 리스트 (핵심)
  Widget _buildDiagnosisSummaryCard(BuildContext context, Color cardColor, TextTheme textTheme, String? title, List<String> symptoms) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.15), width: 1.5), // Subtle Green Border
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.health_and_safety_rounded, color: Theme.of(context).primaryColor, size: 24),
              const SizedBox(width: 8),
              Text(
                '진단 결과',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 진단명 (크게)
          Text(
            title ?? '분석 중...',
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: Colors.black87,
              height: 1.2,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 20),
          
          // 증상 리스트
          if (symptoms.isNotEmpty) ...[
            Wrap(
              spacing: 8.0, 
              runSpacing: 8.0, 
              children: symptoms.map((symptom) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9), // Very Light Green
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFC8E6C9)),
                  ),
                  child: Text(
                    symptom,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ]
        ],
      ),
    );
  }

  // 3번 영역: 마크다운 상세 보고서
  Widget _buildDetailsCard(Color cardColor, TextTheme textTheme, String markdown) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24.0),
      child: MarkdownBody(
        data: markdown,
        styleSheet: MarkdownStyleSheet(
          // 텍스트 스타일 정의
          h1: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, height: 1.5, color: Colors.black87, fontSize: 22),
          h2: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, height: 1.6, color: Colors.black87, fontSize: 19),
          p: textTheme.bodyMedium?.copyWith(height: 1.8, color: Colors.black87, fontSize: 16),
          listBullet: textTheme.bodyMedium?.copyWith(color: Colors.black54),
          
          // ✅ 링크 색상 변경 (기존 Blue -> Secondary or Primary)
          a: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
          
          // 강조 텍스트 (Deep Green)
          strong: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2E7D32)),
          
          blockSpacing: 16,
          h2Padding: const EdgeInsets.only(top: 24, bottom: 12), 
          pPadding: const EdgeInsets.only(bottom: 12),
        ),
      ),
    );
  }
  
  // 하단 버튼들
  Widget _buildActionButtons(BuildContext context, String? caseId) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 2,
            ),
            onPressed: () {
              if (caseId == null){
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('진단 기록이 저장되지 않았습니다.')),
                );                         
                return; 
              }
              Navigator.pushNamed(context, '/chatbot', arguments: {
                'caseId': caseId,
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                 Icon(Icons.chat_bubble_outline, size: 20),
                 SizedBox(width: 8),
                 Text('AI 상담하기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        // 필요 시 다른 버튼 추가 (수의사 상담 등)
      ],
    );
  }
}