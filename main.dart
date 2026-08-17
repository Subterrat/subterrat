import 'package:flutter/material.dart';

import 'api.dart';
import 'home_page.dart';
import 'theme.dart';

/// 後端網址。留空時會用本機產生的示範格子，
/// 這樣 C 的 API 還沒好之前也能把介面做完。
///
/// 執行時可以覆蓋，不用改程式：
///   flutter run --dart-define=API_BASE=https://xxx.run.app
const String kApiBase = String.fromEnvironment('API_BASE', defaultValue: '');

void main() {
  runApp(const SubterratApp());
}

class SubterratApp extends StatelessWidget {
  const SubterratApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SubTerrat',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: HomePage(api: RiskApi(baseUrl: kApiBase)),
    );
  }
}
