import 'package:flutter/material.dart';

import 'data/laws_cache_database.dart';
import 'pages/root_list_page.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LawsCacheDatabase().database;
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B5D7A)),
        fontFamily: kAppSansFont,
        fontFamilyFallback: kAppSansFallback,
        textTheme: ThemeData.light().textTheme.apply(
          fontFamily: kAppSansFont,
          fontFamilyFallback: kAppSansFallback,
        ),
        primaryTextTheme: ThemeData.light().primaryTextTheme.apply(
          fontFamily: kAppSansFont,
          fontFamilyFallback: kAppSansFallback,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: kAppBackgroundColor,
      ),
      home: const RootListPage(),
    );
  }
}
