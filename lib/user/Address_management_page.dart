import 'package:flutter/material.dart';
import '../constants.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: AddressManagementPage(),
  ));
}

class Address {
  int id;
  String name;
  String address1;
  String address2;
  String phone;
  bool isDefault;

  Address({
    required this.id,
    required this.name,
    required this.address1,
    required this.address2,
    required this.phone,
    required this.isDefault,
  });
}

class AddressManagementPage extends StatefulWidget {
  const AddressManagementPage({super.key});

  @override
  State<AddressManagementPage> createState() => _AddressManagementPageState();
}

class _AddressManagementPageState extends State<AddressManagementPage> {
  List<Address> addresses = [];

  @override
  void initState() {
    super.initState();
    loadAddresses();
  }

  // 배송지 조회 api
  Future<List<Address>> fetchUserAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';

    final response = await http.post(
      Uri.parse('$baseUrl/get_user_addresses/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((addr) => Address(
        id: addr['address_id'],
        name: addr['receiver_name'],
        address1: addr['address'],
        address2: addr['detail_address'],
        phone: addr['phone_number'],
        isDefault: addr['is_default'] ?? false,
      )).toList();
    } else {
      throw Exception('주소 목록을 불러오지 못했습니다');
    }
  }

  // 기본 배송지 설정 api
  Future<bool> setDefaultAddress(int addressId) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    final response = await http.post(
      Uri.parse('$baseUrl/set_default_address/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'address_id': addressId,
      }),
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      print('기본 배송지 설정 실패: ${response.body}');
      return false;
    }
  }

  Future<void> loadAddresses() async {
    try {
      final result = await fetchUserAddresses();
      setState(() {
        // 기본 배송지가 먼저 오도록 정렬
        addresses = result..sort((a, b) => b.isDefault ? 1 : 0 - (a.isDefault ? 1 : 0));
      });
    } catch (e) {
      print('주소 로드 실패: $e');
    }
  }

  void _editAddress(int index) async {
    final edited = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditAddressPage(address: addresses[index]),
      ),
    );

    if (edited != null && edited is Address) {
      setState(() {
        addresses[index] = edited;
      });
    }
  }

  // 배송지 삭제 api
  void _deleteAddress(int index) async {
    final addr = addresses[index];

    final response = await http.post(
      Uri.parse('$baseUrl/delete_address/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'address_id': addr.id}),
    );

    if (response.statusCode == 200) {
      setState(() {
        addresses.removeAt(index);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('배송지가 삭제되었습니다.')),
      );
    } else {
      final errorMsg = jsonDecode(response.body)['error'] ?? '삭제 실패';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('배송지 관리', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: addresses.length,
        itemBuilder: (context, index) {
          final addr = addresses[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: addr.isDefault ? Color(0xFFD7763D) : Colors.grey,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                final success = await setDefaultAddress(addr.id);
                if (success) {
                  await loadAddresses();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('기본 배송지 설정에 실패했습니다')),
                  );
                }},
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(addr.name, style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 4),
                    Text(addr.address1),
                    Text(addr.address2),
                    Text(addr.phone),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => _deleteAddress(index),
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFFFEFD3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                            ),
                            child: const Text('삭제', style: TextStyle(color: Colors.black)),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => _editAddress(index),
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFFFEFD2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Text('수정', style: TextStyle(color: Colors.black)),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: ElevatedButton(
          onPressed: () async {
            final added = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddAddressPage()),
            );

            if (added == true) {
              await loadAddresses();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF2DFC2),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('배송지 추가', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF916636),),
          ),
        ),
      )
    );
  }
}

// 배송지 수정 페이지
class EditAddressPage extends StatefulWidget {
  final Address address;
  const EditAddressPage({super.key, required this.address});

  @override
  State<EditAddressPage> createState() => _EditAddressPageState();
}

class _EditAddressPageState extends State<EditAddressPage> {
  late TextEditingController nameCtrl;
  late TextEditingController addr1Ctrl;
  late TextEditingController addr2Ctrl;
  late TextEditingController phoneCtrl;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.address.name);
    addr1Ctrl = TextEditingController(text: widget.address.address1);
    addr2Ctrl = TextEditingController(text: widget.address.address2);
    phoneCtrl = TextEditingController(text: widget.address.phone);
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    addr1Ctrl.dispose();
    addr2Ctrl.dispose();
    phoneCtrl.dispose();
    super.dispose();
  }

  // 배송지 수정 api
  void _saveChanges() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    final response = await http.post(
      Uri.parse('$baseUrl/update_address/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'address_id': widget.address.id,
        'receiver_name': nameCtrl.text,
        'address': addr1Ctrl.text,
        'detail_address': addr2Ctrl.text,
        'phone_number': phoneCtrl.text,
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('배송지 정보가 수정되었습니다.')),
      );

      // 수정된 Address 객체 반환
      Navigator.pop(
        context,
        Address(
          id: widget.address.id,
          name: nameCtrl.text,
          address1: addr1Ctrl.text,
          address2: addr2Ctrl.text,
          phone: phoneCtrl.text,
          isDefault: widget.address.isDefault,
        ),
      );
    } else {
      print('배송지 수정 실패: ${response.body}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('수정 실패. 다시 시도해주세요.')),
      );
    }
  }

  void _openAddressSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddressSearchPage(
          onAddressSelected: (address) {
            print(address);
            setState(() {
              addr1Ctrl.text = address;
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('주소 수정', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '이름')),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: addr1Ctrl,
                    decoration: const InputDecoration(labelText: '주소'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _openAddressSearch,
                  child: const Text('우편번호 검색'),
                ),
              ],
            ),
            TextField(controller: addr2Ctrl, decoration: const InputDecoration(labelText: '상세주소')),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: '전화번호')),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _saveChanges, child: const Text('저장')),
          ],
        ),
      ),
    );
  }
}

// 배송지 추가 페이지
class AddAddressPage extends StatefulWidget {
  const AddAddressPage({super.key});

  @override
  State<AddAddressPage> createState() => _AddAddressPageState();
}

class _AddAddressPageState extends State<AddAddressPage> {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController addr1Ctrl = TextEditingController();
  final TextEditingController addr2Ctrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();

  // 배송지 추가 api
  Future<void> submitAddress() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    // 현재 사용자의 주소 목록 조회
    final checkResponse = await http.post(
      Uri.parse('$baseUrl/get_user_addresses/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );

    // 주소가 없는 경우 기본 배송지로 설정
    bool isDefault = false;
    if (checkResponse.statusCode == 200) {
      final List<dynamic> existingAddresses = jsonDecode(utf8.decode(checkResponse.bodyBytes));
      isDefault = existingAddresses.isEmpty;
    }

    // 주소 등록
    final url = Uri.parse('$baseUrl/add_user_address/');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user': userId,
        'receiver_name': nameCtrl.text,
        'address': addr1Ctrl.text,
        'detail_address': addr2Ctrl.text,
        'phone_number': phoneCtrl.text,
        'is_default': isDefault,
      }),
    );

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('배송지가 등록되었습니다.')),
      );
      Navigator.pop(context, true);
    } else {
      print('주소 등록 실패: ${response.body}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('등록 실패. 다시 시도해주세요.')),
      );
    }
  }

  void _openAddressSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddressSearchPage(
          onAddressSelected: (address) {
            print(address);
            setState(() {
              addr1Ctrl.text = address;
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('주소 추가')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '이름')),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: addr1Ctrl,
                    decoration: const InputDecoration(labelText: '주소'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _openAddressSearch,
                  child: const Text('우편번호 검색'),
                ),
              ],
            ),
            TextField(controller: addr2Ctrl, decoration: const InputDecoration(labelText: '상세주소')),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: '전화번호')),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: submitAddress,
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }
}

// 우편번호 검색 페이지
class AddressSearchPage extends StatefulWidget {
  final void Function(String address) onAddressSelected;

  const AddressSearchPage({super.key, required this.onAddressSelected});

  @override
  State<AddressSearchPage> createState() => _AddressSearchPageState();
}

class _AddressSearchPageState extends State<AddressSearchPage> {
  late final WebViewController _controller;
  late final Future<void> _loadPostcodePage;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'flutter_address_channel',
        onMessageReceived: (message) {
          widget.onAddressSelected(message.message);
          Navigator.pop(context);
        },
      );
    _loadPostcodePage = _loadHtml();
  }

  Future<void> _loadHtml() async {
    final htmlString = await rootBundle.loadString('assets/postcode.html');
    await _controller.loadRequest(
      Uri.dataFromString(
        htmlString,
        mimeType: 'text/html',
        encoding: Encoding.getByName('utf-8'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('주소 검색')),
      body: FutureBuilder<void>(
        future: _loadPostcodePage,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('주소 검색 화면을 불러오지 못했습니다.'));
          }
          return WebViewWidget(controller: _controller);
        },
      ),
    );
  }
}
