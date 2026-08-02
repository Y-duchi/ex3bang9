import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// ML Kit Korean Text Recognition 패키지
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../constants.dart';

class IDPage extends StatefulWidget {
  @override
  _IDPageState createState() => _IDPageState();
}

class _IDPageState extends State<IDPage> {
  File? _image;
  String? name;
  String? idFront;
  String? idBack;
  String? issuedDate;
  bool loading = false;

  late ImagePicker imagePicker;

  @override
  void initState() {
    super.initState();
    imagePicker = ImagePicker();
  }

  // 이미지 선택 (갤러리)
  Future<void> pickImageFromGallery() async {
    final pickedFile = await imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      await performOCR(_image!);
    }
  }

  // 이미지 촬영 (카메라)
  Future<void> captureImageWithCamera() async {
    final pickedFile = await imagePicker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      await performOCR(_image!);
    }
  }

  // OCR 인식
  Future<void> performOCR(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);

    // 한국어 전용 인식기
    final textRecognizer = TextRecognizer(
      script: TextRecognitionScript.korean,
    );

    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();

    final raw = recognizedText.text;
    print('── [OCR 전체 텍스트(raw)] ──\n$raw\n────────────────────');

    // ── 정규표현식 정의 ──

    // 이름: 한 줄에 순수 한글 2~4자(공백 없이)
    final nameRegex  = RegExp(r'^[가-힣]{2,4}$');

    // 주민등록번호: 앞6자리 + (하이픈 또는 유사 대시 또는 공백) + 뒤7자리
    // 예: "960116-238593", "960116‐238593"(유니코드 대시), "960116 238593" 등
    final juminRegex = RegExp(r'^(\d{6})[-‐\s]?(\d{7})$');

    // 날짜: YYYY . MM . DD 혹은 YYYY-MM-DD, 온점/하이픈 앞뒤로 공백 허용
    // 예: "2017.12.12", "2017 . 12 . 12", "2017-12-12" 등
    final dateRegex  = RegExp(r'^(\d{4})\s*[.\-]\s*(\d{1,2})\s*[.\-]\s*(\d{1,2})');

    String? matchedName;
    String? matchedIdFront; // 주민번호 앞 6자리
    String? matchedIdBack;  // 주민번호 뒷 첫 자리(성별 코드)
    String? matchedDate;    // YYYY-MM-DD 포맷으로 저장

    // raw를 줄 단위로 분리해서 검사
    for (final line in raw.split('\n')) {
      final t = line.trim();
      if (t.isEmpty) continue;

      // 1) 이름 매칭
      if (matchedName == null && nameRegex.hasMatch(t)) {
        matchedName = t;
        continue; // 다음 줄로 넘어가서 주민번호/날짜도 검사
      }

      // 2) 주민등록번호 매칭
      //    예: t = "960116-238593" 또는 "960116‐238593" 등
      final jm = juminRegex.firstMatch(t.replaceAll(' ', ''));
      if (matchedIdFront == null && jm != null) {
        matchedIdFront = jm.group(1);         // "960116"
        // jm.group(2)는 "238593" 전체(7자리) → 여기서 첫 글자만 떼어냄
        final fullBack = jm.group(2)!;        // 예: "238593"
        matchedIdBack = fullBack.substring(0, 1); // "2"
        continue;
      }

      // 3) 발급일자 매칭
      //    예: t = "2017.12.12 발급" 또는 "2017 . 12 . 12" 등
      //    일단 줄 내에서 공백을 제거해 본 뒤 매칭 시도
      final normalized = t.replaceAll(' ', '');
      final dm = dateRegex.firstMatch(normalized);
      if (matchedDate == null && dm != null) {
        final y  = dm.group(1)!;      // ex: "2017"
        final mo = dm.group(2)!;      // ex: "12" 또는 "1"
        final d  = dm.group(3)!;      // ex: "12" 또는 "2"
        final month = mo.padLeft(2, '0'); // "1" → "01"
        final day   = d.padLeft(2, '0');  // "2" → "02"
        matchedDate = "$y-$month-$day";   // "2017-12-12"
        continue;
      }
    }

    setState(() {
      name       = matchedName;
      idFront    = matchedIdFront;
      idBack     = matchedIdBack;
      issuedDate = matchedDate;
    });
  }



  // 서버 전송
  Future<void> submitToServer() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    if (userId == null || name == null || idFront == null || idBack == null || issuedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("인식된 정보를 모두 입력해주세요.")),
      );
      return;
    }

    setState(() => loading = true);

    final url = Uri.parse('$baseUrl/verify_id/');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'name': name,
        'issued_date': issuedDate,
        'id_number_front': idFront,
        'id_number_back': idBack,
      }),
    );

    setState(() => loading = false);

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("2차 인증 완료!")));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("서버 오류: ${response.body}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('신분증 촬영')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: captureImageWithCamera,
              child: const Text('신분증 촬영'),
            ),
            const SizedBox(height: 10),
            if (_image != null) Image.file(_image!, width: 200),

            const SizedBox(height: 20),
            const Text("정보 확인", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            buildInfoRow("이름", name),
            buildInfoRow("주민등록번호", idFront != null && idBack != null ? "$idFront-$idBack******" : null),
            buildInfoRow("발급일자", issuedDate),

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: submitToServer,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade100),
              child: const Text('확인', style: TextStyle(color: Colors.black)),
            )
          ],
        ),
      ),
    );
  }

  Widget buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text("$label  ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value ?? '인식되지 않음'),
        ],
      ),
    );
  }
}
