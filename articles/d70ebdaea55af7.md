---
title: "【Flutter】responsive_frameworkを試す"
emoji: "🎥"
type: "tech"
topics:
  - "flutter"
  - "responsive"
  - "dart"
  - "ui"
published: true
published_at: "2022-10-30 03:26"
---

# [responsive_framework](https://pub.dev/packages/responsive_framework)
Flutterアプリを簡単にレスポンシブ対応にしてくれるパッケージになります。
異なるスクリーンサイズにUIを自動的に適応させてくれます。

## 試した環境

```
- macOS Monterey バージョン12.6 Apple M1
- Flutter SDK バージョン 3.3.1
- Google Chrome バージョン 106.0.5249.119
```

## パッケージ導入

```yaml:pubspec.yaml
dependencies:
  responsive_framework: ^0.2.0
```
`pubspec.yaml` に上記を追加し、`flutter pub get` を実施
または、`flutter pub add responsive_framework` を実施します。

## AutoScale
> AutoScaleは、レイアウトをプロポーショナルに縮小・拡大し、UIの外観を正確に保持します。

Flutterはデフォルトで拡大・縮小した場合UIをリサイズする挙動になっています。
例えば `AppBar` の幅は `double.infinity` なので、スクリーンがどれだけ大きくなっても、利用可能な幅を満たすように引き伸ばされます。
また子供のImageウィジェットの幅を `1080` と指定していても、親の要素が `1080` よりも小さい場合、Imageウィジェットは縮小されます。※ 詳細は[こちら](https://docs.flutter.dev/development/ui/layout/constraints)

![](https://storage.googleapis.com/zenn-user-upload/f9c09c4cab80-20221030.gif)


こちらをデフォルトでAutoScaleになるように修正してみます。
```dart
import 'package:responsive_framework/responsive_framework.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      builder: (context, child) =>
            ResponsiveWrapper.builder(child, defaultScale: true), // ←追加
      home: const ResponsivePage(),
    );
  }
}
```
こうする事で↓の様に拡大・縮小にあわせてそのままのレイアウトで拡大・縮小しているのが分かるかと思います。
![](https://storage.googleapis.com/zenn-user-upload/f2f9448edab6-20221030.gif)


:::details 検証用のページはこちら

```dart
import 'package:flutter/material.dart';

class MenuBar extends StatelessWidget {
  const MenuBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          margin: const EdgeInsets.symmetric(vertical: 30),
          child: Row(
            children: <Widget>[
              InkWell(
                onTap: () {},
                child: const Text("HEADER",
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 30,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w500)),
              ),
              Flexible(
                child: Container(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    children: <Widget>[
                      TextButton(
                        onPressed: () {},
                        child: const Text(
                          "HOME",
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text(
                          "DOCS",
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text(
                          "BLOG",
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text(
                          "ABOUT",
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text(
                          "CONTACT",
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
            height: 1,
            margin: const EdgeInsets.only(bottom: 30),
            color: const Color(0xFFEEEEEE)),
      ],
    );
  }
}

class ResponsivePage extends StatelessWidget {
  const ResponsivePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ResponsivePage')),
      body: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: <Widget>[
              const MenuBar(),
              Image.network('https://picsum.photos/1080/667')
            ],
          ),
        ),
      ),
    );
  }
}
```
:::

## Breakpoints
> ブレイクポイントは、異なるスクリーンサイズでのレスポンシブな動作を制御します。

サイズ毎に `Resize` か `AutoScale` かを選択できます。
試しに以下の設定で動作させてみます。

```dart
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      builder: (context, child) => ResponsiveWrapper.builder(
        child,
        maxWidth: 1100, // ← 追加
        minWidth: 480, // ← 追加
        breakpoints: [ // ← 追加
          const ResponsiveBreakpoint.resize(480, name: MOBILE),
          const ResponsiveBreakpoint.autoScale(800, name: TABLET),
          const ResponsiveBreakpoint.resize(1000, name: DESKTOP),
        ],
      ),
      home: const ResponsivePage(),
    );
  }
}
```
↑の例だと
- 480 以下は Resize  (※ `defaultScale: true` が設定されていれば AutoScale )
- 480 - 800 までは Resize
- 800 - 1000 までは AutoScale
- 1000以上は Resize
    - ただ、maxWidthが1100になっているのでそれ以上は描画されない

の様な動きになります。↓実際の挙動がこちらになります。

![](https://storage.googleapis.com/zenn-user-upload/73c2fc643968-20221030.gif)

`AutoScale` の使いどころとして  `MOBILE`  と  `DESKTOP` の間 (=`TABLET`) やより大きい画面の時にスケールさせると望ましい表示になるらしいです。
※  `MOBILE`  や  `DESKTOP` の名前は  `responsive_framework` 内で定義されているもので、カスタム名を設定する事もできます。

## ResponsiveRowColumn
responsive_framework ではレスポンシブ用のウィジェットがいくつか用意されています。
`ResponsiveRowColumn` では名前の通りサイズに応じて `Row` / `Column` を切り替えてくれるウィジェットになります。

試しに以下を実装してみます。
```dart
class ResponsivePage extends StatelessWidget {
  const ResponsivePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ResponsivePage')),
      body: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: <Widget>[
              const MenuBar(),
              Image.network('https://picsum.photos/600/300'),
              DefaultTextStyle(
                style: const TextStyle(
                    color: Colors.black,
                    fontSize: 25,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w500),
                child: ResponsiveRowColumn(
                  rowMainAxisAlignment: MainAxisAlignment.center,
                  rowPadding: const EdgeInsets.all(30),
                  columnPadding: const EdgeInsets.all(30),
                  layout: ResponsiveWrapper.of(context).isSmallerThan(DESKTOP)
                      ? ResponsiveRowColumnType.COLUMN
                      : ResponsiveRowColumnType.ROW,
                  children: const [
                    ResponsiveRowColumnItem(
                      rowFlex: 1,
                      child: Text('WORK1'),
                    ),
                    ResponsiveRowColumnItem(
                      rowFlex: 1,
                      child: Text('WORK2'),
                    ),
                    ResponsiveRowColumnItem(
                      rowFlex: 1,
                      child: Text('WORK3'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```
`WORK1`, `WORK2`, `WORK3` のレイアウトを、`DESKTOP` よりも小さい場合は `COLUMN` レイアウトで、大きい場合は `ROW` レイアウトで表示するように設定しています。
※ ちなみに言わずもがなだとは思いますが、 `rowXXXX` となっているのは `ROW` の時の設定、`columnXXXX` は `COLUMN` の時の設定になります。 
↓実際に動作させてみるとレイアウトが変化しているのが分かるかと思います。

![](https://storage.googleapis.com/zenn-user-upload/131d4ca32826-20221030.gif)

## ResponsiveGridView
`ResponsiveGridView` はグリッドアイテム間の幅などを考慮してサイズに応じていい感じにグリッド表示してくれるウィジェットになります。

```dart
              Container(
                color: Colors.lime,
                child: ResponsiveGridView.builder(
                  itemCount: _items.length,
                  padding: const EdgeInsets.all(8.0),
                  shrinkWrap: true,
                  gridDelegate: const ResponsiveGridDelegate(
                      crossAxisSpacing: 50,
                      mainAxisSpacing: 50,
                      minCrossAxisExtent: 150),
                  itemBuilder: (BuildContext context, int index) =>
                      Container(color: Colors.grey),
                ),
              ),
```
上記実装を追加し、実際に動作させると以下の様になります。
※ `ResponsiveBreakpoint` での切り替えは一旦なしでデフォルトの `Resize` の動作になります

![](https://storage.googleapis.com/zenn-user-upload/21d0b1975f91-20221030.gif)

↑の場合スクロールするViewの最大高が未設定なので、`shrinkWrap` を `true` に設定しておく必要があります。

### 高さ固定の場合
maxのheightが決まっている場合 ScrollViewの `shrinkWrap` [プロパティ](https://api.flutter.dev/flutter/widgets/ScrollView/shrinkWrap.html)と同様に `false` に設定する必要があります。

```dart
              Container(
                width: double.infinity,
                height: 500,
                color: Colors.lime,
                child: ResponsiveGridView.builder(
                  itemCount: _items.length,
                  padding: const EdgeInsets.all(8.0),
                  shrinkWrap: false,
                  gridDelegate: const ResponsiveGridDelegate(
                      crossAxisSpacing: 50,
                      mainAxisSpacing: 50,
                      minCrossAxisExtent: 150),
                  itemBuilder: (BuildContext context, int index) =>
                      Container(color: Colors.grey),
                ),
              ),
```
↑の場合、高さ `500` 固定で `shrinkWrap` を `false` に設定しています。

![](https://storage.googleapis.com/zenn-user-upload/86bc0542bd89-20221030.gif)

## ResponsiveValue
`ResponsiveValue` はサイズに応じて値を切り替える事ができます。
試しにサイズ毎に異なるフォントサイズを設定してみたいと思います。
先ほど `ResponsiveRowColumn` での `DefaultTextStyle` を使って設定してみます。

```dart
              DefaultTextStyle(
                style: TextStyle(
                    color: Colors.black,
                    fontSize: ResponsiveValue( // ← 追加
                      context,
                      defaultValue: 25.0,
                      valueWhen: const [
                        Condition.smallerThan(name: MOBILE, value: 10.0),
                        Condition.largerThan(name: TABLET, value: 40.0)
                      ],
                    ).value,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w500),
```
↑ `Condition.smallerThan(name: MOBILE, value: 10.0)` で  `MOBILE` より小さい場合はフォントサイズが `10.0` になる様に、 `Condition.largerThan(name: TABLET, value: 40.0)` で `TABLET` より大きい場合はフォントサイズが `40.0` になるよに設定しています。

![](https://storage.googleapis.com/zenn-user-upload/f3cc7b79b139-20221030.gif)

 