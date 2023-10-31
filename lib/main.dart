import 'dart:html';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:neis/neis.dart';
import 'package:http/http.dart' as http;
import 'package:xml2json/xml2json.dart';

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
              ColorScheme.fromSeed(seedColor: Color.fromARGB(255, 0, 0, 0)),
        ),
        home: LoginPage(),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {
  Future<List<Menu>>? current;

  void getNext(String schoolCode) {
    // schoolCode 파라미터 추가
    current = getMealInfo(schoolCode: schoolCode); // schoolCode 전달
    notifyListeners();
  }

  var favorites = <Future>[];

  void toggleFavorite() {
    if (favorites.contains(current)) {
      favorites.remove(current);
    } else {
      favorites.add(current!);
    }
    notifyListeners();
  }
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
  final String schoolCode;
  MyHomePage({required this.schoolCode}) : super();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (selectedIndex) {
      case 0:
        page = LunchPage(schoolCode: widget.schoolCode);
        break;
      case 1:
        page = FavoritesPage();
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

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
  const LoginPage({Key? key}) : super(key: key);
}

class _LoginPageState extends State<LoginPage> {
  final schoolNameController = TextEditingController();
  String schoolName = "";
  String schoolCode = "";

  Future<void> handleLogin(BuildContext context) async {
    // BuildContext를 매개변수로 전달
    // 학교 이름이 입력되었는지 확인
    if (schoolNameController.text.isEmpty) {
      showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          // 대화상자를 위한 별도의 BuildContext 사용
          return AlertDialog(
            title: Text('Error'),
            content: Text('학교 이름을 입력해주세요.'),
            actions: <Widget>[
              TextButton(
                child: Text('확인'),
                onPressed: () {
                  Navigator.of(dialogContext)
                      .pop(); // context 대신 dialogContext 사용
                },
              )
            ],
          );
        },
      );
    } else {
      var schoolInfo = await getSchoolInfo(schoolNameController.text);
      print(schoolCode);
      print(schoolCode.runtimeType);

      if (schoolInfo != null) {
        print(schoolInfo["schoolInfo"]["row"][0]["SD_SCHUL_CODE"]);
        schoolCode = schoolInfo["schoolInfo"]["row"][0]["SD_SCHUL_CODE"];

        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => MyHomePage(schoolCode: schoolCode)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('로그인')),
      body: Column(
        children: <Widget>[
          TextField(
            controller: schoolNameController,
            decoration: InputDecoration(labelText: '학교 이름을 입력하세요'),
          ),
          ElevatedButton(
            onPressed: () => handleLogin(context),
            child: Text('로그인'),
          )
        ],
      ),
    );
  }
}

Future<Map<String, dynamic>?> getSchoolInfo(String schoolName) async {
  var apiKey = "19eb100a427641a7b682dd943562b0ad"; // 여기에 실제 인증 키를 입력해야 합니다.

  // NEIS API URL 구성
  var url =
      "https://open.neis.go.kr/hub/schoolInfo?Type=json&pIndex=1&pSize=100&SCHUL_NM=$schoolName&KEY=$apiKey";

  // HTTP GET 요청
  Dio dio = Dio();
  var response = await dio.get(url);

  if (response.statusCode == 200) {
    print(response.data);
    // JSON 형식으로 변환

    return jsonDecode(response.data); // JSON 반환
  } else {
    print("학교 정보를 불러오는데 실패했습니다.");
    return null;
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

Future<List<Menu>> getMealInfo({required String schoolCode}) async {
  final DateTime today = DateTime.now();
  final year = today.year;
  final month = today.month;

  var schoolInfo = await getSchoolInfo(schoolCode); // 학교 정보 가져오기

  if (schoolInfo != null) {
    final school = Neis(
      Region.gyeonggi,
      "key",
      schoolInfo["schoolInfo"]["row"]['SCHUL_NM'], // 학교 이름 사용
      SchoolType.his.toString(),
    );

    List mealsData = await school.getMeals(year, month);

    // mealsData 리스트 안에 있는 데이터로 Menu 객체 리스트 생성
    print(mealsData);
    List<Menu> menus = mealsData.map((meal) {
      return Menu(meal['name'], meal['allergenInfo']);
      // 'name'과 'allergenInfo'는 실제 데이터의 키 이름에 따라 변경해야 합니다.
    }).toList();

    return menus;
  } else {
    throw Exception("급식정보를 가져오는 것을 실패했습니다.");
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
        for (var mealInfo in appState.favorites)
          ListTile(
            leading: Icon(Icons.favorite),
            title: Text(mealInfo.toString()),
          ),
      ],
    );
  }
}

class LunchPage extends StatelessWidget {
  final String schoolCode;
  LunchPage({required this.schoolCode});

  final DateTime today = DateTime.now();
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    // 급식 정보를 비동기로 가져와서 표시
    return FutureBuilder<List<Menu>>(
      future: getMealInfo(schoolCode: schoolCode),
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
                SizedBox(height: 15),
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
