// lib/shopping/ar_page.dart
import 'dart:math' as math;
import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

class ARPage extends StatefulWidget {
  final String modelPath;
  final String productName;

  const ARPage({super.key, required this.modelPath, required this.productName});

  @override
  State<ARPage> createState() => _ARPageState();
}

class _ARPageState extends State<ARPage> {
  static const _modelChannel = MethodChannel('bang9/ar_model');

  ARKitController? arkitController;
  ARKitReferenceNode? node;

  double currentScale = 0.03;
  double currentRotationY = 0.0;
  bool isFurniturePlaced = false;
  bool isValidatingModel = true;
  String? modelError;
  String statusMessage = '3D 모델을 확인하고 있어요.';

  /// SceneView를 완전히 리빌드하기 위한 key
  Key sceneViewKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _validateModel();
  }

  @override
  void dispose() {
    arkitController?.dispose();
    super.dispose();
  }

  Future<void> _validateModel() async {
    if (mounted) {
      setState(() {
        isValidatingModel = true;
        modelError = null;
        statusMessage = '3D 모델을 확인하고 있어요.';
      });
    }

    try {
      await _modelChannel.invokeMapMethod<String, dynamic>('validateModel', {
        'path': widget.modelPath,
      });
      if (!mounted) return;
      setState(() {
        isValidatingModel = false;
        statusMessage = '바닥을 천천히 비추면 가구가 배치돼요.';
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        isValidatingModel = false;
        modelError = error.message ?? '3D 모델을 불러오지 못했습니다.';
        statusMessage = '3D 모델을 불러오지 못했습니다.';
      });
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        isValidatingModel = false;
        modelError = 'AR 모델 검증 기능은 iPhone에서만 사용할 수 있습니다.';
      });
    }
  }

  void onARKitViewCreated(ARKitController controller) {
    arkitController = controller;
    controller.onError = _handleARKitError;
    controller.addCoachingOverlay(CoachingOverlayGoal.horizontalPlane);
    controller.onAddNodeForAnchor = _handleAnchor;
  }

  void _handleARKitError(String? message) {
    if (!mounted) return;
    setState(() {
      modelError = message ?? '알 수 없는 ARKit 오류가 발생했습니다.';
      statusMessage = 'ARKit 오류가 발생했습니다.';
    });
  }

  void _handleAnchor(ARKitAnchor anchor) {
    if (anchor is! ARKitPlaneAnchor ||
        isValidatingModel ||
        modelError != null ||
        isFurniturePlaced)
      return;

    isFurniturePlaced = true;
    _placeFurniture(anchor);
  }

  Future<void> _placeFurniture(ARKitPlaneAnchor anchor) async {
    if (node != null) {
      await arkitController?.remove(node!.name);
    }

    node = ARKitReferenceNode(
      url: widget.modelPath,
      scale: vector.Vector3.all(currentScale),
      eulerAngles: vector.Vector3(0, currentRotationY, 0),
    );

    try {
      await arkitController?.add(node!, parentNodeName: anchor.nodeName);
      if (!mounted) return;
      setState(() => statusMessage = '가구가 바닥에 배치됐어요.');
    } catch (error) {
      isFurniturePlaced = false;
      if (!mounted) return;
      setState(() {
        modelError = '가구 배치에 실패했습니다: $error';
        statusMessage = '가구 배치에 실패했습니다.';
      });
    }
  }

  void _scaleModel(double factor) {
    final newScale = currentScale * factor;
    const min = 0.005, max = 0.1;
    if (newScale < min || newScale > max) return;

    setState(() {
      currentScale = newScale;
      node?.scale = vector.Vector3.all(currentScale);
    });
  }

  void _rotateModel(double delta) {
    setState(() {
      currentRotationY += delta;
      node?.eulerAngles = vector.Vector3(0, currentRotationY, 0);
    });
  }

  void _resetPlacement() {
    // 노드 삭제
    if (node != null) {
      arkitController?.remove(node!.name);
      node = null;
    }
    // ARKitController 재생성 준비
    arkitController?.dispose();
    setState(() {
      arkitController = null;
      sceneViewKey = UniqueKey();
      isFurniturePlaced = false;
      statusMessage = '바닥을 천천히 비추면 가구가 배치돼요.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AR 가구 배치')),
      body: Stack(
        children: [
          if (!isValidatingModel && modelError == null)
            ARKitSceneView(
              key: sceneViewKey,
              planeDetection: ARPlaneDetection.horizontal,
              showFeaturePoints: true,
              onARKitViewCreated: onARKitViewCreated,
            ),

          if (isValidatingModel)
            const Center(child: CircularProgressIndicator()),

          if (modelError != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 40),
                        const SizedBox(height: 12),
                        Text(
                          widget.productName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(modelError!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _validateModel,
                          child: const Text('다시 확인'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 확대/축소/회전/재배치 버튼
          if (!isValidatingModel && modelError == null)
            Positioned(
              bottom: 100,
              left: 20,
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: () => _scaleModel(1.2),
                    child: const Text('확대'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _scaleModel(1 / 1.2),
                    child: const Text('축소'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _rotateModel(math.pi / 8),
                    child: const Text('회전'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _resetPlacement,
                    child: const Text('재배치'),
                  ),
                ],
              ),
            ),

          // 하단 안내 텍스트
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(10),
              color: Colors.black54,
              child: Text(
                statusMessage,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
