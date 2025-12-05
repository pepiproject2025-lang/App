// lib/pages/diag_page.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // ✅ 교체
import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';


class DiagPage extends StatefulWidget {
  const DiagPage({super.key});
  @override
  State<DiagPage> createState() => _DiagPageState();
}

class _DiagPageState extends State<DiagPage> {
  final _nameCtrl = TextEditingController();
  final _ageCtrl  = TextEditingController();
  Uint8List? _pickedBytes;

  final _picker = ImagePicker(); // ✅ image_picker 인스턴스

  Future<void> _pickImage() async {
    // 갤러리에서 이미지 선택 (웹에서도 동작)
    final XFile? xfile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048, // 선택: 리사이즈 (웹/모바일 공통)
      maxHeight: 2048,
      imageQuality: 90, // 선택: JPEG 압축 (0~100)
    );
    if (xfile != null) {
      final bytes = await xfile.readAsBytes(); // ✅ 웹/모바일 공통
      setState(() => _pickedBytes = bytes);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration() => InputDecoration(
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    hintText: '',
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.black.withOpacity(0.15), width: 1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.black.withOpacity(0.15), width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 1.2),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final vh = MediaQuery.of(context).size.height;
    const maxInnerWidth = 420.0;

    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: vh, maxWidth: maxInnerWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단 뒤로가기
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new),
                      splashRadius: 22,
                      onPressed: () => Navigator.pop(context),
                    ),

                    Expanded(
                      child: Center(
                        child: Image.asset(
                          'assets/logo_img.png',
                          height: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 50),

                const Text('이름', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: _inputDecoration().copyWith(hintText: '이름을 입력하세요'),
                ),
                const SizedBox(height: 18),

                // const Text('나이', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                // const SizedBox(height: 8),
                // TextFormField(
                //   controller: _ageCtrl,
                //   keyboardType: TextInputType.number,
                //   decoration: _inputDecoration().copyWith(hintText: '나이를 입력하세요'),
                // ),
                // const SizedBox(height: 22),

                // 업로드 박스
                GestureDetector(
                  onTap: _pickImage, // ✅ image_picker 사용
                  child: Container(
                    height: 250,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE0E0E0), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _pickedBytes == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF0F7FF),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.add_a_photo_rounded, size: 40, color: Color(0xFF4A90E2)),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                '사진을 업로드해주세요',
                                style: TextStyle(color: Color(0xFF757575), fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.memory(_pickedBytes!, fit: BoxFit.cover),
                          ),
                  ),
                ),

                const SizedBox(height: 24),
                const SizedBox(height: 30),

                // 진단하기 버튼
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    onPressed: () async {
                      if (_pickedBytes == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('안구 사진을 먼저 업로드해주세요.')),
                        );
                        return;
                      }

                      // 화면에 보여줄 값들 미리 저장
                      final Uint8List imageBytes = _pickedBytes!;
                      final String petName = _nameCtrl.text;

                      // 1) 먼저 로딩 페이지로 이동
                      Navigator.pushNamed(context, '/loading');

                      try {
                        // 2) 로딩 페이지가 떠 있는 동안 백엔드에 진단 요청
                        final resultData = await _requestDiagnosis(imageBytes);

                        if (!context.mounted) return;

                        // 3) 로딩 페이지 닫기
                        Navigator.pop(context);

                        // 4) 결과 페이지로 이동 (마크다운 + 이름 + 이미지 전달)
                        Navigator.pushNamed(
                          context,
                          '/result',
                          arguments: {
                            'markdown': resultData['model_output'],
                            'diagnosis': resultData['diagnosis'],
                            'case_id': resultData['case_id'],
                            'name': petName,
                            'imageBytes': imageBytes,
                          },
                        );
                      } catch (e) {
                        if (!context.mounted) return;

                        // 에러가 나도 로딩 페이지는 닫아주기
                        Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('진단 요청 실패: $e')),
                        );
                      }
                    },
                    child: const Text(
                      '진단 요청하기',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );

  }
  // ✅ 백엔드 호출 함수
  Future<Map<String, dynamic>> _requestDiagnosis(Uint8List imageBytes) async {
    // TODO: 실제 백엔드 주소로 변경
    // - 웹에서 테스트: http://localhost:8000/predict
    // - 안드로이드 에뮬레이터: http://10.0.2.2:8000/predict
    final uri = Uri.parse('http://localhost:8000/predict');

    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        http.MultipartFile.fromBytes(
          'image', // FastAPI의 파라미터 이름과 동일해야 함
          imageBytes,
          filename: 'eye.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      )
      ..fields['note'] = _nameCtrl.text; // 선택사항: note로 이름 보내기

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception('Backend error: ${response.statusCode}');
    }
    print('RAW BODY = ${response.body}');
    final body = jsonDecode(response.body);
    final data = body['data'];
    final modelOutput = data?['model_output'];
    final diagnosis = data?['diagnosis'];
    final caseId = data?['case_id'];
    
    return {
      'model_output': modelOutput?.toString().trim() ?? '',
      'diagnosis': diagnosis, // Map or null
      'case_id': caseId,
    };
  }
}
