import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'api.dart';
import 'home_page.dart';
import 'maps_bootstrap.dart';
import 'theme.dart';

/// 後端網址。留空時會用本機產生的示範格子，
/// 這樣 C 的 API 還沒好之前也能把介面做完。
///
/// 執行時可以覆蓋，不用改程式：
///   flutter run --dart-define=API_BASE=https://xxx.run.app
const String kApiBase = String.fromEnvironment('API_BASE', defaultValue: '');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // .env 是 gitignored 的本機檔案（見 .env.example）。還沒建立時不擋啟動，
  // 只是地圖金鑰會是空字串，maps_bootstrap 會直接跳過注入 script。
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // 沒有 .env 也要能把介面跑起來，只是地圖不會顯示。
  }
  await loadGoogleMapsScript(dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '');
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
