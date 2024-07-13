---
title: "【Flutter】Google Maps 上に円や矩形でエリア表示"
emoji: "🟢"
type: "tech" # tech: 技術記事 / idea: アイデア
topics:
  - "flutter"
  - "dart"
  - "android"
  - "ios"
  - "googlemap"
published: true
---
# 概要

[google_maps_flutter](https://pub.dev/packages/google_maps_flutter) を使って地図上に、円や矩形でエリア表示を試してみたいと思います。

# 必要なパッケージインストール

`pubspec.yaml` に以下を追加、又は `flutter pub add google_maps_flutter` でインストールします。

```yaml
dependencies:
  google_maps_flutter: ^2.7.0
```

# 円でエリア表示する

地図上に円を表示するにはGoogleMapクラスの[circles](https://pub.dev/documentation/google_maps_flutter/latest/google_maps_flutter/GoogleMap/circles.html)プロパティに `Set<Circle>` を渡します。

## Circleクラス

https://pub.dev/documentation/google_maps_flutter/latest/google_maps_flutter/Circle-class.html

- circleId
  - Circleを一意に識別する為に[CircleId](https://pub.dev/documentation/google_maps_flutter/latest/google_maps_flutter/CircleId-class.html)を設定します
- center
  - Circleの中心位置を[LatLng](https://pub.dev/documentation/google_maps_flutter/latest/google_maps_flutter/LatLng-class.html)で設定します
- radius
  - 円の半径をメートル単位で指定する。デフォルト値は0

## サンプル実装

早速円を地図上に表示してみたいと思います。

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GoogleMapsFlutterCircles extends StatefulWidget {
  const GoogleMapsFlutterCircles({super.key});

  @override
  State<GoogleMapsFlutterCircles> createState() =>
      GoogleMapsFlutterCirclesState();
}

class GoogleMapsFlutterCirclesState extends State<GoogleMapsFlutterCircles> {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();

  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(35.68123428932672, 139.76714355230686),
    zoom: 14.4746,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Google Maps Flutter Circles')),
      body: GoogleMap(
        mapType: MapType.normal,
        initialCameraPosition: _initialCameraPosition,
        onMapCreated: (GoogleMapController controller) {
          _controller.complete(controller);
        },
        circles: {
          Circle(
            circleId: const CircleId('circle_1'),
            center: const LatLng(35.68123428932672, 139.76714355230686),
            radius: 500,
            fillColor: Colors.red.withOpacity(0.5),
            strokeWidth: 5,
          ),
        },
      ),
    );
  }
}
```

Cameraの初期位置を中心に半径500mを円で囲むような実装にしてます。

これを実行すると↓のようになりました。円も地図の拡大・縮小に応じています。

![image1.gif](/images/fd0ddbf10df177/image1.gif =350x)

# 矩形でエリア表示する

地図上に矩形でエリア表示するにはGoogleMapクラスの[polygons](https://pub.dev/documentation/google_maps_flutter/latest/google_maps_flutter/GoogleMap/polygons.html)プロパティに `Set<Polygon>` を渡します。

## Polygonクラス

https://pub.dev/documentation/google_maps_flutter/latest/google_maps_flutter/Polygon-class.html

- polygonId
  - Polygonを一意に識別する為に[PolygonId](https://pub.dev/documentation/google_maps_flutter/latest/google_maps_flutter/PolygonId-class.html)を設定します
- points
  - 描画する多角形の頂点を `List<LatLng>` で設定します
- holes
  - 名前の通り矩形内に複数の穴を開ける設定ができる
  - `List<List<LatLng>>` で設定る

## サンプル実装

まずはシンプルに中心点を囲ったPolygonを表示してみたいと思います。

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GoogleMapsFlutterPolygon extends StatefulWidget {
  const GoogleMapsFlutterPolygon({super.key});

  @override
  State<GoogleMapsFlutterPolygon> createState() =>
      GoogleMapsFlutterPolygonState();
}

class GoogleMapsFlutterPolygonState extends State<GoogleMapsFlutterPolygon> {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();

  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(35.68123428932672, 139.76714355230686),
    zoom: 14.4746,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Google Maps Flutter Polygon')),
      body: GoogleMap(
        mapType: MapType.normal,
        initialCameraPosition: _initialCameraPosition,
        onMapCreated: (GoogleMapController controller) {
          _controller.complete(controller);
        },
        polygons: {
          Polygon(
            polygonId: const PolygonId('polygonId'),
            points: const [
              LatLng(35.684072, 139.765456), // 北西
              LatLng(35.684072, 139.768794), // 北東
              LatLng(35.678400, 139.768794), // 南東
              LatLng(35.678400, 139.765456), // 南西
            ],
            strokeWidth: 2,
            strokeColor: Colors.red,
            fillColor: Colors.blue.withOpacity(0.5),
          ),
        },
      ),
    );
  }
}
```

実行すると↓の様になります。

![image2.gif](/images/fd0ddbf10df177/image2.gif =350x)

次に `holes` を指定して矩形内に穴を開けてみたいと思います。

先ほどの `Polygon` に以下内容で `holes` を指定します。

```dart
            holes: const [
              [
                LatLng(35.682072, 139.766456), // 北西
                LatLng(35.682072, 139.767456), // 北東
                LatLng(35.681072, 139.767456), // 南東
                LatLng(35.681072, 139.766456), // 南西
              ],
              [
                LatLng(35.680072, 139.767456), // 北西
                LatLng(35.680072, 139.768456), // 北東
                LatLng(35.679072, 139.768456), // 南東
                LatLng(35.679072, 139.767456), // 南西
              ],
            ],
```

実行すると↓の様に矩形内に2つの穴が空いているのが確認できるかと思います。

![image3.gif](/images/fd0ddbf10df177/image3.gif =350x)

# 参考URL

https://medium.com/@rishi_singh/how-to-create-polygon-polyline-circle-and-marker-on-google-maps-flutter-720ea5338e02