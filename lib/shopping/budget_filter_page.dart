import 'package:flutter/material.dart';
import 'budget_result_page.dart';

class BudgetFilterPage extends StatefulWidget {
  const BudgetFilterPage({super.key});

  @override
  State<BudgetFilterPage> createState() => _BudgetFilterPageState();
}

class _BudgetFilterPageState extends State<BudgetFilterPage> {
  final TextEditingController _budgetController = TextEditingController();
  List<String> selectedFurnitureTypes = [];
  String selectedCategory = '전체';

  final List<String> furnitureTypes = [
    '침대', '책상', '쇼파', '의자',
    '조명', '옷장', '선반', '화장대',
    '식탁', '잡화',
  ];

  final List<String> categories = ['전체', '러블리', '모던', '우디', '레트로'];

  void toggleFurnitureType(String type) {
    setState(() {
      if (selectedFurnitureTypes.contains(type)) {
        selectedFurnitureTypes.remove(type);
      } else {
        selectedFurnitureTypes.add(type);
      }
    });
  }

  void selectCategory(String category) {
    setState(() {
      selectedCategory = category;
    });
  }

  Widget buildTable(List<String> items, List<String> selectedItems, Function(String) toggle, {bool singleSelect = false}) {
    const int columns = 4;
    int rows = (items.length / columns).ceil();

    List<TableRow> tableRows = [];
    for (int i = 0; i < rows; i++) {
      List<Widget> rowChildren = [];
      for (int j = 0; j < columns; j++) {
        int index = i * columns + j;
        if (index < items.length) {
          final item = items[index];
          final isSelected = singleSelect
              ? selectedCategory == item
              : selectedItems.contains(item);
          rowChildren.add(
            GestureDetector(
              onTap: () => toggle(item),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFF5E4B8) : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(item, style: const TextStyle(fontSize: 14)),
              ),
            ),
          );
        } else {
          rowChildren.add(Container());
        }
      }

      tableRows.add(TableRow(
        children: rowChildren.map((child) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: SizedBox(height: 36, child: child),
          );
        }).toList(),
      ));
    }

    return Table(children: tableRows);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 예산 내 추천', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: const BackButton(),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('예산 입력'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _budgetController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: '예산을 입력해주세요.',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const Text('원'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('원하는 가구 선택'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: buildTable(furnitureTypes, selectedFurnitureTypes, toggleFurnitureType),
                  ),
                  const SizedBox(height: 24),
                  const Text('가구 카테고리 선택'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: buildTable(categories, [], selectCategory, singleSelect: true),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: screenWidth,
            height: 70, // 버튼 영역 더 크게
            decoration: const BoxDecoration(
              color: Color(0xFFF5E4B8),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: TextButton(
              onPressed: () {
                final budget = int.tryParse(_budgetController.text) ?? 0;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BudgetResultPage(
                      budget: budget,
                      furnitureTypes: selectedFurnitureTypes,
                      category: selectedCategory,
                    ),
                  ),
                );
              },
              child: const Align(
                alignment: Alignment.topCenter, // 텍스트 위로 정렬
                child: Padding(
                  padding: EdgeInsets.only(top: 13), // 텍스트 위치 조정
                  child: Text(
                    '완료',
                    style: TextStyle(color: Colors.brown, fontSize: 16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}