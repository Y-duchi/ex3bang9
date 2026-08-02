import 'package:flutter/material.dart';

class RegionFilterDialog extends StatefulWidget {
  const RegionFilterDialog({super.key});

  @override
  State<RegionFilterDialog> createState() => _RegionFilterDialogState();
}

class _RegionFilterDialogState extends State<RegionFilterDialog> {
  String? selectedProvince;
  final Set<String> selectedDistricts = {};

  final Map<String, List<String>> regionMap = {
    '경기도': ['가평군','고양시','과천시','광명시','광주시','구리시','군포시','김포시',
            '남양주시','동두천시','부천시','성남시','수원시','시흥시','안산시','안성시','안양시','양주시',
            '양평군','여주시','연천군','오산시','용인시','의왕시','의정부시','이천시','파주시','평택시','포천시','하남시','화성시'],
    '강원도':['강릉시','고성군','동해시','삼척시','속초시','약구군','양양군','영월군',
            '원주시','인제군','정선군','철원군','춘천시','태백시','평창군','홍천군','화천군','회성군'],
    '서울특별시': ['강남구', '강동구', '강북구', '강서구', '관악구','광진구','구로구','금천구',
                '노원구','도봉구','동대문구','동작구','마포구','서대문구','서초구','성동구','성북구','송파구',
                '양천구','영등포구','용산구','은평구','종로구','중구','중랑구'],
    '대전광역시': ['대덕구','동구','서구','유성구','중구'],
    '광주광역시':['광산구','남구','동구','북구','서구'],
    '울산광역시': ['남구','동구','북구','울주군','중구'],
    '부산광역시': ['강서구','금정구','기장군','남구','동구','동래구','부산진구','북구',
                '사상구','사하구','서구','수영구','연제구','영도구','중구','해운대구'],
    '대구광역시':['남구','달서구','달성군','동구','북구','서구','수성구','중구'],
    '충청남도': ['계룡시','공주시','금산군','논산시','당진시','보령시','부여군','서산시',
              '서천군','세종시','아산시','예산군','천안시','청양군','태안군','홍성군'],
    '충청북도':['괴산군','단양군','보은군','영동군','옥천군','음성군','제천시','증평군','친천군',
              '청주시','충주시'],
    '전라남도':['강진군','고흥군','곡성군','광양시','구례군','나주시','담양군','목포시','무안군','보성군',
              '순천시','신안군','여수시','영광군','영암군','완도군','장성군','장흥군','진도군','함평군','해남군','화순군'],
    '전라북도': ['고창군','군산시','김제시','남원시','무주군','부안군','순창군','완주군','익산시',
              '임실군','장수군','전주시','정읍시','진안군'],
    '경상북도':['경산시','경주시','고령군','구미시','군위군','김천시','문경시','봉화군','상주시',
            '성주군','안동시','영덕군','영양군','영주시','영천시','예천군','울릉군','울진군','의성군','청도군',
            '청송군','칠곡군','포항시'],
    '경상남도':['거제시','거창군','고성군','김해시','남해군','밀양시','사천시','산청군','양산시','의령군',
              '진주시','창녕군','창원시','통영시','하동군','함안군','함양군','합천군'],
    '제주도': ['서귀포시','제주시'],
  };

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.only(left: 60, top: 80, bottom: 80),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: const Text('지역선택', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          Expanded(
            child: Row(
              children: [
                // 시/도 리스트
                Expanded(
                  flex: 1,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: regionMap.keys.map((province) {
                      final isSelected = province == selectedProvince;
                      return GestureDetector(
                        onTap: () => setState(() {
                          selectedProvince = province;
                          selectedDistricts.clear();
                        }),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.orange[200] : Colors.white,
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(province),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                // 시/군/구 리스트
                Expanded(
                  flex: 2,
                  child: selectedProvince == null
                      ? const Center(child: Text('시/도를 먼저 선택해주세요'))
                      : ListView(
                    padding: const EdgeInsets.all(8),
                    children: regionMap[selectedProvince]!.map((district) {
                      final isChecked = selectedDistricts.contains(district);
                      return CheckboxListTile(
                        value: isChecked,
                        title: Text(district),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              selectedDistricts.add(district);
                            } else {
                              selectedDistricts.remove(district);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context, {
                    'province': selectedProvince,
                    'districts': selectedDistricts,
                  });
                },
                child: const Text('확인'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
