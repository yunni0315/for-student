//import 'dart:js';
//import 'dart:html';
//import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: 'Namer App',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme:
              ColorScheme.fromSeed(seedColor: Color.fromARGB(255, 74, 101, 90)),
        ),
        home: MyHomePage(),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {
  var current = getMealInfo();

  void getNext() {
    current = getMealInfo();
    notifyListeners();
  }

  var favorites = <Future>[];

  void toggleFavorite() {
    if (favorites.contains(current)) {
      favorites.remove(current);
    } else {
      favorites.add(current);
    }
    notifyListeners();
  }
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (selectedIndex) {
      //case 0:
      //  page = GeneratorPage();
      //  break;
      case 0:
        page = FavoritesPage();
        break;
      case 1:
        page = LunchPage();
        break;
      default:
        throw UnimplementedError('no widget for $selectedIndex');
    }
    return LayoutBuilder(builder: (context, constraints) {
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              child: NavigationRail(
                extended: constraints.maxWidth >= 600,
                destinations: [
                  NavigationRailDestination(
                    icon: Icon(Icons.favorite),
                    label: Text('Favorites'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.dining),
                    label: Text('Lunch'),
                  ),
                ],
                selectedIndex: selectedIndex,
                onDestinationSelected: (value) {
                  setState(() {
                    selectedIndex = value;
                  });
                },
              ),
            ),
            Expanded(
              child: Container(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: page,
              ),
            ),
          ],
        ),
      );
    });
  }
}

class Menu {
  String name;
  String allergenInfo;

  Menu(this.name, this.allergenInfo);

  @override
  String toString() {
    return '$name ($allergenInfo)';
  }
}

Future<List<Menu>> getMealInfo({String schoolCode = '7530126'}) async {
  final DateTime today = DateTime.now();
  final String dateStr = DateFormat('yyMMdd').format(today);

  final response = await http.get(Uri.parse(
      'https://open.neis.go.kr/hub/mealServiceDietInfo?Type=json&ATPT_OFCDC_SC_CODE=J10&SD_SCHUL_CODE=$schoolCode&MLSV_YMD=$dateStr'));

  if (response.statusCode == 200) {
    final Map<String, dynamic> data = json.decode(response.body);

    try {
      final List<Menu> menus = genMenuBodyWithStr(data);
      return menus;
    } catch (e) {
      throw Exception('급식 정보가 없습니다.');
    }
  } else {
    throw Exception('HTTP 요청 실패: ${response.statusCode}');
  }
}

List<Menu> genMenuBodyWithStr(Map<String, dynamic> data) {
  List<Menu> body = [];
  String menuTmp;

  for (menuTmp
      in data["mealServiceDietInfo"][1]["row"][0]["DDISH_NM"].split('<br/>')) {
    List<String> parts = menuTmp.split(" (");

    if (parts.length == 1) {
      body.add(Menu(parts[0], ""));
    } else {
      body.add(Menu(parts[0], parts[1]));
    }
  }

  return body;
}

class BigCard extends StatelessWidget {
  const BigCard({
    Key? key,
    required this.mealInfo,
  });

  final String mealInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.displayMedium!.copyWith(
      color: theme.colorScheme.onPrimary,
    );

    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text(
          mealInfo, // 급식 정보를 여기에 표시
          style: style,
        ),
      ),
    );
  }
}

class FavoritesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    if (appState.favorites.isEmpty) {
      return Center(
        child: Text('No favorites yet.'),
      );
    }

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text('You have '
              '${appState.favorites.length} favorites:'),
        ),
        for (var pair in appState.favorites)
          ListTile(
            leading: Icon(Icons.favorite),
            title: Text(pair.toString()),
          ),
      ],
    );
  }
}

class LunchPage extends StatelessWidget {
  final DateTime today = DateTime.now();
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    // 급식 정보를 비동기로 가져와서 표시
    return FutureBuilder<List<Menu>>(
      future: getMealInfo(schoolCode: '7530126'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Text('오류: ${snapshot.error}');
        } else {
          List<Menu> mealInfo = snapshot.data ?? [];
          String combinedMealInfo =
              mealInfo.map((menu) => menu.toString()).join('\n');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BigCard(mealInfo: combinedMealInfo),
                SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        appState.toggleFavorite();
                      },
                      icon: Icon(Icons.dining),
                      label: Text('Lunch'),
                    ),
                    SizedBox(width: 10),
                  ],
                ),
              ],
            ),
          );
        }
      },
    );
  }
}
