import 'package:flutter/material.dart';
import '../constants.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

class SellFormPage extends StatefulWidget {
  final String? postId;

  const SellFormPage({super.key, this.postId});

  @override
  State<SellFormPage> createState() => _SellFormPageState();
}

class _SellFormPageState extends State<SellFormPage> {
  final titleController = TextEditingController();
  final priceController = TextEditingController();
  final addressController = TextEditingController();
  final contentController = TextEditingController();

  String userId = '';

  final ImagePicker _picker = ImagePicker();
  List<XFile> _images = [];

  final List<String> categoryList = [
    '조명', '쇼파', '책상', '의자', '침대',
    '옷장', '선반', '식탁', '화장대', '잡화'
  ];

  String? selectedCategory;
  String tradeType = '판매';
  String directTrade = '직거래 가능';

  Future<void> _pickImage() async {
    if (_images.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진은 최대 10장까지 추가할 수 있어요.')),
      );
      return;
    }

    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _images.add(image);
      });
    }
  }

  LatLng? _currentLatLng;
  String selectedAddress = '선택한 주소';
  late GoogleMapController _mapController;
  Marker? _marker;

  @override
  void initState() {
    super.initState();
    loadUserId();
    _getCurrentLocation();
    if (widget.postId != null) {
      _loadPostData(widget.postId!);
    }
  }

  Future<void> _loadPostData(String postId) async {
    final url = Uri.parse('$baseUrl/used_furniture/$postId/');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));

      setState(() {
        titleController.text = data['title'] ?? '';
        selectedCategory = data['category'];
        tradeType = data['transaction_type'] ?? '판매';
        priceController.text = (data['price'] ?? '').toString();
        directTrade = (data['is_direct_trade'] ?? true) ? '직거래 가능' : '직거래 불가능';
        selectedAddress = data['address'] ?? '선택한 주소';
        addressController.text = data['detail_address'] ?? '';
        contentController.text = data['content'] ?? '';

        final lat = (data['latitude'] != null) ? double.tryParse(data['latitude'].toString()) : null;
        final lng = (data['longitude'] != null) ? double.tryParse(data['longitude'].toString()) : null;
        if (lat != null && lng != null) {
          _currentLatLng = LatLng(lat, lng);
          _marker = Marker(markerId: MarkerId('selected'), position: _currentLatLng!);
        }
      });
    } else {
      print('게시글 불러오기 실패: ${response.statusCode}');
    }
  }

  // 로그인한 유저 ID 불러오기
  Future<void> loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('user_id') ?? '';
    });
  }

  // 중고가구 게시글 작성
  Future<void> submitPost() async {
    if (widget.postId == null) {
      final url = Uri.parse('$baseUrl/create_used_furniture/');
      final request = http.MultipartRequest('POST', url);


      // 데이터 추가
      request.fields['user_id'] = userId;
      request.fields['title'] = titleController.text;
      request.fields['category'] = selectedCategory ?? '';
      request.fields['transaction_type'] = tradeType;
      request.fields['price'] = priceController.text;
      request.fields['is_direct_trade'] = (directTrade == '직거래 가능').toString();
      request.fields['address'] = selectedAddress;
      request.fields['detail_address'] = addressController.text;
      request.fields['content'] = contentController.text;
      request.fields['latitude'] = _marker?.position.latitude.toString() ?? '';
      request.fields['longitude'] =
          _marker?.position.longitude.toString() ?? '';

      // 이미지 추가
      for (var image in _images) {
        request.files.add(
            await http.MultipartFile.fromPath('images', image.path));
      }

      // 전송
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        print('등록 성공');
        Navigator.pop(context);
      } else {
        print('등록 실패: ${response.statusCode}');
        print(response.body);
      }
    } else {
      final url = Uri.parse('$baseUrl/used_furniture/${widget.postId}/');
      final request = http.MultipartRequest('PUT', url);

      request.fields['user_id'] = userId;
      request.fields['title'] = titleController.text;
      request.fields['category'] = selectedCategory ?? '';
      request.fields['transaction_type'] = tradeType;
      request.fields['price'] = priceController.text;
      request.fields['is_direct_trade'] = (directTrade == '직거래 가능').toString();
      request.fields['address'] = selectedAddress;
      request.fields['detail_address'] = addressController.text;
      request.fields['content'] = contentController.text;
      request.fields['latitude'] = _marker?.position.latitude.toString() ?? '';
      request.fields['longitude'] = _marker?.position.longitude.toString() ?? '';

      // 이미지 추가 (기존 추가된 이미지들만 전송)
      for (var image in _images) {
        request.files.add(await http.MultipartFile.fromPath('images', image.path));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        print('수정 성공');
        Navigator.pop(context);
      } else {
        print('수정 실패: ${response.statusCode}');
        print(response.body);
      }
    }
  }



  // 구글맵 관련 함수
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) return;
    }

    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentLatLng = LatLng(position.latitude, position.longitude);
      _marker = Marker(markerId: MarkerId('selected'), position: _currentLatLng!);
    });

    _updateAddressFromLatLng(_currentLatLng!);
  }

  void _onCameraMove(CameraPosition position) {
    setState(() {
      _marker = Marker(markerId: MarkerId('selected'), position: position.target);
    });
  }

  void _onCameraIdle() {
    if (_marker != null) {
      _updateAddressFromLatLng(_marker!.position);
    }
  }

  Future<void> _updateAddressFromLatLng(LatLng latLng) async {
    List<Placemark> placemarks = await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
    if (placemarks.isNotEmpty) {
      final placemark = placemarks[0];

      // 시, 동/읍/면만 조합
      final simpleAddress = '${placemark.locality} ${placemark.subLocality}';

      setState(() {
        selectedAddress = simpleAddress;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF916636);

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 가구 팔기', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0.5,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('사진 추가'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._images.map((image) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(image.path),
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                )),
                if (_images.length < 10)
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.grey[100],
                      ),
                      child: const Center(
                        child: Icon(Icons.add_a_photo_outlined, size: 30, color: Colors.grey),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${_images.length}/10', style: const TextStyle(color: Colors.grey)),

            const SizedBox(height: 16),

            // 제목
            const Text('제목'),
            const SizedBox(height: 8),
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                hintText: '제목을 입력하세요.',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),

            const SizedBox(height: 16),

            // 카테고리 선택
            const Text('가구 카테고리 선택'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: categoryList.contains(selectedCategory) ? selectedCategory : null,
              hint: const Text("카테고리를 선택하세요."),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: categoryList.map((e) {
                return DropdownMenuItem(value: e, child: Text(e));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedCategory = value;
                });
              },
            ),

            const SizedBox(height: 16),

            // 거래 방식
            const Text('거래 방식'),
            const SizedBox(height: 8),
            Row(
              children: ['판매', '나눔'].map((type) {
                final selected = tradeType == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(type),
                    selected: selected,
                    selectedColor: activeColor,
                    labelStyle: TextStyle(color: selected ? Colors.white : Colors.black),
                    onSelected: (_) => setState(() => tradeType = type),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // 가격 입력
            if (tradeType == '판매') ...[
              const Text('가격'),
              const SizedBox(height: 8),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '₩ 가격을 입력하세요.',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 직거래 여부
            const Text('직거래'),
            const SizedBox(height: 8),
            Row(
              children: ['직거래 가능', '직거래 불가능'].map((option) {
                final selected = directTrade == option;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(option),
                    selected: selected,
                    selectedColor: activeColor,
                    labelStyle: TextStyle(color: selected ? Colors.white : Colors.black),
                    onSelected: (_) => setState(() => directTrade = option),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // 지도
            const Text('지역'),
            const SizedBox(height: 8),
            GestureDetector(
              onPanDown: (_) {}, // 스크롤 막기
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _currentLatLng == null
                    ? const Center(child: CircularProgressIndicator())
                    : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentLatLng!,
                    zoom: 16,
                  ),
                  markers: _marker != null ? {_marker!} : {},
                  onCameraMove: _onCameraMove,
                  onCameraIdle: _onCameraIdle,
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                    Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 주소 + 상세주소 입력 가로 정렬
            Row(
              crossAxisAlignment: CrossAxisAlignment.end, // 👈 높이 기준 하단 정렬
              children: [
                // 선택된 주소 (읽기 전용 하단선만 있는 스타일)
                Expanded(
                  flex: 1,
                  child: TextField(
                    readOnly: true,
                    controller: TextEditingController(text: selectedAddress),
                    style: const TextStyle(fontSize: 13, color: Colors.black),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: UnderlineInputBorder(),
                      contentPadding: EdgeInsets.only(bottom: 10), // 하단 맞춤
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                // 상세주소 입력 (하단선, 작게)
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: addressController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: '상세주소 입력',
                      isDense: true,
                      contentPadding: EdgeInsets.only(bottom: 10),
                      border: UnderlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 설명
            const Text('자세한 설명'),
            const SizedBox(height: 8),
            TextField(
              controller: contentController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: '게시글 내용을 작성해 주세요.\n(판매 금지 물품은 게시가 제한될 수 있어요.)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: ElevatedButton(
          onPressed: submitPost,
          style: ElevatedButton.styleFrom(
            backgroundColor: activeColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('작성 완료'),
        ),
      ),
    );
  }
}