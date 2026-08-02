import 'shopping/product_detail.dart';
import 'used/detail_used.dart';
import 'user/Order_List.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'community/post_detail_page.dart';
import 'firebase_options.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'login/login_screen.dart';
import 'constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portfolio builds are fully local: no Firebase or social-login traffic.
  if (!portfolioDemo) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if (kakaoNativeAppKey.isNotEmpty) {
      KakaoSdk.init(
        nativeAppKey: kakaoNativeAppKey,
        javaScriptAppKey: kakaoJavaScriptAppKey,
      );
    }
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '방꾸석',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.5,
        ),
        colorScheme: const ColorScheme.light(
          primary: Colors.brown,
          background: Colors.white,
        ),
        fontFamily: 'Pretendard',
      ),
      home: const LoginScreen(),
      routes: {
        // 커뮤니티 게시글 상세
        '/community/post_detail_page': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return PostDetailPage(
            postId: args['postId'],
            title: args['title'],
            content: args['content'],
            createdAt: args['createdAt'],
            userId: args['userId'],
            nickname: args['nickname'],
            likeCount: args['likeCount'],
            commentCount: args['commentCount'],
            isInitiallyLiked: args['isInitiallyLiked'],
            images: args['images'] ?? [],
          );
        },

        '/used/detail_used': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return UsedDetailPage(
            postId: args['postId'],
            isLiked: args['isLiked'] ?? false,
            onToggleLike: args['onToggleLike'] ?? (_) {},
          );
        },

        // 주문 상세
        '/user/Order_List': (context) => const OrderPage(),

        ///상세 이동
        '/product/detail': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return ProductDetailPage(
            productId: args['productId'],
            productName: args['productName'],
            isLiked: args['isLiked'],
            onToggleLike: args['onToggleLike'],
          );
        },
      },
    );
  }
}
