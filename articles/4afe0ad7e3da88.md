---
title: "【Flutter】auto_routeを試す"
emoji: "🛣️"
type: "tech"
topics:
  - "flutter"
  - "dart"
  - "router"
published: true
published_at: "2022-09-30 23:56"
---

# [auto_route](https://pub.dev/packages/auto_route)
[go_router](https://pub.dev/packages/go_router)と並んでよく目にするauto_routeを今回は試してみたいと思います。

auto_router
> - Flutterのナビゲーションパッケージ
> - 強い型付けの引数を渡すことができる
> - 楽にディープリンクができる
> - コード生成を使ってルート設定を簡素化する

## 動作環境
動作確認は全てFlutter WebでビルドしてChrome上で確認してます。

```
- macOS Monterey バージョン12.1 Apple M1
- Flutter SDK バージョン 3.3.1
- auto_route バージョン 5.0.1
- Google Chrome バージョン 105.0.5195.125 （arm64）
```

## パッケージインストール

```yml:pubspec.yaml
dependencies:              
  auto_route: ^5.0.1

dev_dependencies:              
  auto_route_generator: ^5.0.1
  build_runner:
```

# まずはシンプルなサンプルを作成
## 遷移用の画面作成

- HomePage
    - アプリ起動時のデフォルトページ
- UserPage

```dart:home_page.dart
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'HomePage',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton(
          child: const Text('UserPageへ'),
          onPressed: () => context.router.pushNamed("/user-page"),
        ),
      ),
    );
  }
}
```

```dart:user_page.dart
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

class UserPage extends StatelessWidget {
  const UserPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'UserPage',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('HomePageへ'),
          onPressed: () => context.router.pop(),
        ),
      ),
    );
  }
}
```

## router.dart の作成

```dart
import 'package:auto_route/auto_route.dart';
import 'package:flutter_web_example/pages/home_page.dart';
import 'package:flutter_web_example/pages/user_page.dart';

@AdaptiveAutoRouter(
  replaceInRouteName: 'Page,Route',
  routes: <AutoRoute>[
    AutoRoute(page: HomePage, initial: true),
    AutoRoute(page: UserPage),
  ],
)
class $AppRouter {}
```

ここまで作成したら、以下で `build_runner build` を実行します。
```sh
$ fvm flutter pub pub run build_runner build --delete-conflicting-outputs
```
すると以下の様な `router.gr.dart` が作成されます。

:::details 作成された router.gr.dart

```dart
// **************************************************************************
// AutoRouteGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouteGenerator
// **************************************************************************
//
// ignore_for_file: type=lint

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i3;
import 'package:flutter/material.dart' as _i4;
import 'package:flutter_web_example/pages/home_page.dart' as _i1;
import 'package:flutter_web_example/pages/user_page.dart' as _i2;

class AppRouter extends _i3.RootStackRouter {
  AppRouter([_i4.GlobalKey<_i4.NavigatorState>? navigatorKey])
      : super(navigatorKey);

  @override
  final Map<String, _i3.PageFactory> pagesMap = {
    HomeRoute.name: (routeData) {
      return _i3.AdaptivePage<dynamic>(
        routeData: routeData,
        child: const _i1.HomePage(),
      );
    },
    UserRoute.name: (routeData) {
      return _i3.AdaptivePage<dynamic>(
        routeData: routeData,
        child: const _i2.UserPage(),
      );
    },
  };

  @override
  List<_i3.RouteConfig> get routes => [
        _i3.RouteConfig(
          HomeRoute.name,
          path: '/',
        ),
        _i3.RouteConfig(
          UserRoute.name,
          path: '/user-page',
        ),
      ];
}

/// generated route for
/// [_i1.HomePage]
class HomeRoute extends _i3.PageRouteInfo<void> {
  const HomeRoute()
      : super(
          HomeRoute.name,
          path: '/',
        );

  static const String name = 'HomeRoute';
}

/// generated route for
/// [_i2.UserPage]
class UserRoute extends _i3.PageRouteInfo<void> {
  const UserRoute()
      : super(
          UserRoute.name,
          path: '/user-page',
        );

  static const String name = 'UserRoute';
}
```
:::

次に `main.dart` を以下に修正します。

```dart
import 'package:flutter/material.dart';
import 'package:flutter_web_example/router/router.gr.dart';

void main() {
  runApp(const MyApp());
}

final _appRouter = AppRouter();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Flutter Web Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      routerDelegate: _appRouter.delegate(),
      routeInformationParser: _appRouter.defaultRouteParser(),
    );
  }
}
```
ここまでで実行すると以下の様に画面遷移します。
![](https://storage.googleapis.com/zenn-user-upload/fbb596181f72-20220930.gif)



# 型付けの引数を渡す
`user_page.dart` に名前を引数で渡せる様に修正します。

```dart
class UserPage extends StatelessWidget {
  const UserPage({super.key, required this.name}); // コンストラクタの引数追加

  final String name; // 追加

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'UserPage $name', // 引数のnameを表示
        ),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('HomePageへ'),
          onPressed: () => context.router.pushNamed("/"),
        ),
      ),
    );
  }
}
```
この状態でもう一度 `build` します。
```sh
$ fvm flutter pub pub run build_runner build --delete-conflicting-outputs
```
この時の `router.gr.dart` の差分としては以下になります。
```diff
--- a/lib/router/router.gr.dart
+++ b/lib/router/router.gr.dart
@@ -29,9 +29,13 @@ class AppRouter extends _i3.RootStackRouter {
       );
     },
     UserRoute.name: (routeData) {
+      final args = routeData.argsAs<UserRouteArgs>();
       return _i3.AdaptivePage<dynamic>(
         routeData: routeData,
-        child: const _i2.UserPage(),
+        child: _i2.UserPage(
+          key: args.key,
+          name: args.name,
+        ),
       );
     },
   };
@@ -63,12 +67,34 @@ class HomeRoute extends _i3.PageRouteInfo<void> {
 
 /// generated route for
 /// [_i2.UserPage]
-class UserRoute extends _i3.PageRouteInfo<void> {
-  const UserRoute()
-      : super(
+class UserRoute extends _i3.PageRouteInfo<UserRouteArgs> {
+  UserRoute({
+    _i4.Key? key,
+    required String name,
+  }) : super(
           UserRoute.name,
           path: '/user-page',
+          args: UserRouteArgs(
+            key: key,
+            name: name,
+          ),
         );
 
   static const String name = 'UserRoute';
 }
+
+class UserRouteArgs {
+  const UserRouteArgs({
+    this.key,
+    required this.name,
+  });
+
+  final _i4.Key? key;
+
+  final String name;
+
+  @override
+  String toString() {
+    return 'UserRouteArgs{key: $key, name: $name}';
+  }
+}
```

`UserRouteArgs`  というclassが追加されており、`UserRoute` でargsにセットする様に変更されています。

`user_page.dart` へ遷移させる部分を以下の様に修正します。
```dart
context.router.push(UserRoute(name: 'taro')),
```
↓動作させてみると引数が渡っている事が確認できます。
![](https://storage.googleapis.com/zenn-user-upload/f43e1d6b4919-20220930.gif)


この時 `pushName` などで必須のパラメータを渡さずに画面遷移しようとすると以下のエラーが発生します。
```
Uncaught (in promise) Error: UserRouteArgs can not be null because it has a required parameter
```

# Tab Navigation
次に `BottomNavigationBar` の選択状態がルートと連動する様なサンプルを試してみます。
実際のサンプルイメージとしては↓の様な挙動になります。
![](https://storage.googleapis.com/zenn-user-upload/19ca37c84f03-20220930.gif)

## Nested Navigation を作成する
`tab_page.dart` の中にネストした `tab1_page.dart`、`tab2_page.dart`、`tab3_page.dart` の3つが存在する様な構成で作成します。`router.dart` に以下を追加します。

```dart
    AutoRoute(
      path: '/tab',
      page: TabPage,
      children: [
        AutoRoute(path: 'tab1', page: Tab1Page, initial: true),
        AutoRoute(path: 'tab2', page: Tab2Page),
        AutoRoute(path: 'tab3', page: Tab3Page),
      ],
    ),
```

## AutoTabsRouterを使ったページ作成
以下内容で `tab_page.dart` を作成します。

```dart
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_example/router/router.gr.dart';

class TabPage extends StatelessWidget {
  const TabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AutoTabsRouter(
      routes: const [Tab1Route(), Tab2Route(), Tab3Route()],
      builder: (context, child, animation) {
        final tabsRouter = AutoTabsRouter.of(context);
        return Scaffold(
            body: FadeTransition(
              opacity: animation,
              child: child,
            ),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: tabsRouter.activeIndex,
              onTap: (index) {
                tabsRouter.setActiveIndex(index);
              },
              items: const [
                BottomNavigationBarItem(label: 'Tab1', icon: Icon(Icons.check)),
                BottomNavigationBarItem(label: 'Tab2', icon: Icon(Icons.check)),
                BottomNavigationBarItem(label: 'Tab3', icon: Icon(Icons.check)),
              ],
            ));
      },
    );
  }
}
```

各タブで表示するページも作成します。
```dart:tab1_page.dart
import 'package:flutter/material.dart';

class Tab1Page extends StatelessWidget {
  const Tab1Page({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      child: const Text('Tab1'),
    );
  }
}
```
↑の要領で、 `tab2_page.dart`、`tab3_page.dart` も作成しときます。
次に `build_runner build` して `router.gr.dart` を更新します。

```sh
$ fvm flutter pub pub run build_runner build --delete-conflicting-outputs
```

:::details 更新された router.gr.dart

```diff
--- a/lib/router/router.gr.dart
+++ b/lib/router/router.gr.dart
@@ -11,26 +11,30 @@
 // ignore_for_file: type=lint
 
 // ignore_for_file: no_leading_underscores_for_library_prefixes
-import 'package:auto_route/auto_route.dart' as _i3;
-import 'package:flutter/material.dart' as _i4;
+import 'package:auto_route/auto_route.dart' as _i7;
+import 'package:flutter/material.dart' as _i8;
 import 'package:flutter_web_example/pages/home_page.dart' as _i1;
+import 'package:flutter_web_example/pages/tab_page.dart' as _i3;
+import 'package:flutter_web_example/pages/tabs/tab1_page.dart' as _i4;
+import 'package:flutter_web_example/pages/tabs/tab2_page.dart' as _i5;
+import 'package:flutter_web_example/pages/tabs/tab3_page.dart' as _i6;
 import 'package:flutter_web_example/pages/user_page.dart' as _i2;
 
-class AppRouter extends _i3.RootStackRouter {
-  AppRouter([_i4.GlobalKey<_i4.NavigatorState>? navigatorKey])
+class AppRouter extends _i7.RootStackRouter {
+  AppRouter([_i8.GlobalKey<_i8.NavigatorState>? navigatorKey])
       : super(navigatorKey);
 
   @override
-  final Map<String, _i3.PageFactory> pagesMap = {
+  final Map<String, _i7.PageFactory> pagesMap = {
     HomeRoute.name: (routeData) {
-      return _i3.AdaptivePage<dynamic>(
+      return _i7.AdaptivePage<dynamic>(
         routeData: routeData,
         child: const _i1.HomePage(),
       );
     },
     UserRoute.name: (routeData) {
       final args = routeData.argsAs<UserRouteArgs>();
-      return _i3.AdaptivePage<dynamic>(
+      return _i7.AdaptivePage<dynamic>(
         routeData: routeData,
         child: _i2.UserPage(
           key: args.key,
@@ -38,24 +42,76 @@ class AppRouter extends _i3.RootStackRouter {
         ),
       );
     },
+    TabRoute.name: (routeData) {
+      return _i7.AdaptivePage<dynamic>(
+        routeData: routeData,
+        child: const _i3.TabPage(),
+      );
+    },
+    Tab1Route.name: (routeData) {
+      return _i7.AdaptivePage<dynamic>(
+        routeData: routeData,
+        child: const _i4.Tab1Page(),
+      );
+    },
+    Tab2Route.name: (routeData) {
+      return _i7.AdaptivePage<dynamic>(
+        routeData: routeData,
+        child: const _i5.Tab2Page(),
+      );
+    },
+    Tab3Route.name: (routeData) {
+      return _i7.AdaptivePage<dynamic>(
+        routeData: routeData,
+        child: const _i6.Tab3Page(),
+      );
+    },
   };
 
   @override
-  List<_i3.RouteConfig> get routes => [
-        _i3.RouteConfig(
+  List<_i7.RouteConfig> get routes => [
+        _i7.RouteConfig(
           HomeRoute.name,
           path: '/',
         ),
-        _i3.RouteConfig(
+        _i7.RouteConfig(
           UserRoute.name,
           path: '/user-page',
         ),
+        _i7.RouteConfig(
+          TabRoute.name,
+          path: '/tab',
+          children: [
+            _i7.RouteConfig(
+              '#redirect',
+              path: '',
+              parent: TabRoute.name,
+              redirectTo: 'tab1',
+              fullMatch: true,
+            ),
+            _i7.RouteConfig(
+              Tab1Route.name,
+              path: 'tab1',
+              parent: TabRoute.name,
+            ),
+            _i7.RouteConfig(
+              Tab2Route.name,
+              path: 'tab2',
+              parent: TabRoute.name,
+            ),
+            _i7.RouteConfig(
+              Tab3Route.name,
+              path: 'tab3',
+              parent: TabRoute.name,
+            ),
+          ],
+        ),
       ];
 }
 
 /// generated route for
 /// [_i1.HomePage]
-class HomeRoute extends _i3.PageRouteInfo<void> {
+class HomeRoute extends _i7.PageRouteInfo<void> {
   const HomeRoute()
       : super(
           HomeRoute.name,
@@ -67,9 +123,9 @@ class HomeRoute extends _i3.PageRouteInfo<void> {
 
 /// generated route for
 /// [_i2.UserPage]
-class UserRoute extends _i3.PageRouteInfo<UserRouteArgs> {
+class UserRoute extends _i7.PageRouteInfo<UserRouteArgs> {
   UserRoute({
-    _i4.Key? key,
+    _i8.Key? key,
     required String name,
   }) : super(
           UserRoute.name,
@@ -89,7 +145,7 @@ class UserRouteArgs {
     required this.name,
   });
 
-  final _i4.Key? key;
+  final _i8.Key? key;
 
   final String name;
 
@@ -98,3 +154,52 @@ class UserRouteArgs {
     return 'UserRouteArgs{key: $key, name: $name}';
   }
 }
+
+/// generated route for
+/// [_i3.TabPage]
+class TabRoute extends _i7.PageRouteInfo<void> {
+  const TabRoute({List<_i7.PageRouteInfo>? children})
+      : super(
+          TabRoute.name,
+          path: '/tab',
+          initialChildren: children,
+        );
+
+  static const String name = 'TabRoute';
+}
+
+/// generated route for
+/// [_i4.Tab1Page]
+class Tab1Route extends _i7.PageRouteInfo<void> {
+  const Tab1Route()
+      : super(
+          Tab1Route.name,
+          path: 'tab1',
+        );
+
+  static const String name = 'Tab1Route';
+}
+
+/// generated route for
+/// [_i5.Tab2Page]
+class Tab2Route extends _i7.PageRouteInfo<void> {
+  const Tab2Route()
+      : super(
+          Tab2Route.name,
+          path: 'tab2',
+        );
+
+  static const String name = 'Tab2Route';
+}
+
+/// generated route for
+/// [_i6.Tab3Page]
+class Tab3Route extends _i7.PageRouteInfo<void> {
+  const Tab3Route()
+      : super(
+          Tab3Route.name,
+          path: 'tab3',
+        );
+
+  static const String name = 'Tab3Route';
+}
```
:::

この状態で実行すると↑の様な挙動になるかと思います。

# 値を返す
値を返す方法としては以下の2通りあります。
1. pop completer を使う

    ```dart
    // LoginRoute内でpopする際に値を渡す
    router.pop(true);  
    
    //  呼び出し側で結果を受け取る
    var result = await router.push(LoginRoute());
    ```
    ↑だとdynamic型になってしまうので、型定義をする場合は以下の様にする
    ```dart
    // route定義
    AutoRoute<bool>(page: LoginPage), 
    
    // LoginRoute内
    router.pop<bool>(true); 
    // 呼び出し側
    var result = await router.push<bool>(LoginRoute()); 
    ```
2. 画面遷移先にcallbackを渡す

```dart
// 画面遷移先
// onRateBook をcallbackとして渡してもらう
class BookDetailsPage extends StatelessWidget {
 const BookDetailsRoute({this.book, required this.onRateBook});

  final Book book;
  final void Function(int) onRateBook;
  ...
  // popする際にcallbackを呼び出す
  onRateBook(RESULT);
  context.router.pop();

// 呼び出し時
context.router.push(
      BookDetailsRoute(
          book: book,
          onRateBook: (rating) {
           // handle result
          }),
    );
```

# Path ParametersとQuery Parameters
ちなみに `AutoRoute` で `path` を指定していない場合 `page` の名前を元にpathが設定されます。
```dart
// 例
AutoRoute(page: HomePage, initial: true), // => initial: trueなのでパスは / になる
AutoRoute(page: UserPage), // page名から /user-page になる
AutoRoute(path: '/sample', page: SamplePage), // pathが指定されているので /sample になる
```
auto_routeでは path の設定はoptionalという扱いになっている様です。
次に、Path Parametersとして何かしら値を渡す場合は以下の様に定義します。

```dart
// 例
AutoRoute(path: '/books/:id', page: BookDetailsPage),   
```
↑の例だと `:id` に設定された値 (例 `/books/9` => `:id` は9が設定される) がBookDetailsPageで取得する事ができます。
先ほどの `HomePage` と `UserPage` を使って試してみたいと思います。

先ずは `router.dart` を以下に修正し、`build runner build` します
```dart
@AdaptiveAutoRouter(
  replaceInRouteName: 'Page,Route',
  routes: <AutoRoute>[
    AutoRoute(page: HomePage, initial: true),
    AutoRoute(path: '/user/:id', page: UserPage), // ← ここを修正!!
    AutoRoute(
      path: '/tab',
      page: TabPage,
      children: [
        AutoRoute(path: 'tab1', page: Tab1Page, initial: true),
        AutoRoute(path: 'tab2', page: Tab2Page),
        AutoRoute(path: 'tab3', page: Tab3Page),
      ],
    ),
  ],
)
class $AppRouter {}
```
`home_page.dart` と `user_page.dart` をそれぞれ以下に修正します。
```dart:home_page.dart
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'HomePage',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column( // ↓ここから下修正 !!
          children: [
            ElevatedButton(
              child: const Text('UserPage1へ'),
              onPressed: () => context.router.pushNamed('/user/1'),
            ),
            const SizedBox(
              height: 8,
            ),
            ElevatedButton(
              child: const Text('UserPage2へ'),
              onPressed: () => context.router.pushNamed('/user/2?name=jiro'),
            ),
          ],
        ),
      ),
    );
  }
}
```

```dart:user_page.dart
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

class UserPage extends StatelessWidget {
  const UserPage({
    super.key,
    @PathParam('id') this.id = -1, // ← 追加!!
    @queryParam this.name = '-',  // ← 追加!! @QueryParamではなく@queryParam
  });

  final int id; // ← 追加!!
  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'UserPage $id / $name',  // ← 修正!!
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('HomePageへ'),
          onPressed: () => context.router.pop(),
        ),
      ),
    );
  }
}
```
この状態でビルドして動かしてみると以下の様な挙動になるかと思います。
![](https://storage.googleapis.com/zenn-user-upload/4f96bc4e7e2c-20221002.gif)


URLの `:id` で指定した部分が渡っているのが確認できるかと思います。
また、`@queryParam` というのも指定しており、名前からして想像できるようにクエリパラメータを扱うものになります。
「UserPage2へ」の時の遷移先に `/user/2?name=jiro` と指定しており、nameの値が `@queryParam this.name` に渡ってくる様な挙動になっています。

また少し分かりづらいですが、`@QueryParam` ではなく `@queryParam` を指定するとプロパティ名をキーとして使ってくれます。`@PathParam` も同様です。

```dart
// 例
@queryParam this.name //=> @QueryParam('name') this.name と同じ
@PathParam('id') this.id // => @pathParam this.id と同じ
```


# Custom Route Transitions
自身で画面遷移のエフェクトを使いたい場合は `CustomRoute` を使用して
`transitionsBuilder` を設定します。

```dart
    CustomRoute(
        path: '/custom'_transition,
        page: CustomTransitionPage,
        transitionsBuilder: TransitionsBuilders.fadeIn),
``` 

# 参考URL
- [Flutter Navigation made easy with auto_route 2.0.x | Medium](https://gbaccetta.medium.com/complex-flutter-navigation-with-nested-routers-and-bottom-bar-navigation-made-easy-with-7f546d33fc4d)
- [Flutter Navigation with AutoRoute | by Türker Gürel | ITNEXT](https://itnext.io/manage-your-navigation-with-autoroute-in-flutter-cc72df48b137)