---
title: "【Dart】作成できるプロジェクトテンプレートを試す"
emoji: "📋"
type: "tech" # tech: 技術記事 / idea: アイデア
topics:
  - "dart"
  - "cli"
published: false
---
# 概要
Dartで新規にプロジェクトを作成してみようと思った時に、使えるテンプレートが何種類かあったので折角なら全部試してみようと思い、全種類を試してみました。

# 試した環境

```bash
$ sw_vers
ProductName: macOS
ProductVersion: 13.4.1
ProductVersionExtra: (c)
BuildVersion: 22F770820d
$ dart --version                              
Dart SDK version: 3.1.5 (stable) (Tue Oct 24 04:57:17 2023 +0000) on "macos_arm64"
```

# プロジェクトテンプレートの種類

プロジェクト作成時のコマンドは `dart create` になります。

どの様なオプションがあるのか確認してみます。

```bash
$ dart create --help
Create a new Dart project.

Usage: dart create [arguments] <directory>
-h, --help                       Print this usage information.
-t, --template                   The project template to use.

          [console] (default)    A command-line application.
          [package]              A package containing shared Dart libraries.
          [server-shelf]         A server app using package:shelf.
          [web]                  A web app that uses only core Dart libraries.

    --[no-]pub                   Whether to run 'pub get' after the project has been
                                 created.
                                 (defaults to on)
    --force                      Force project generation, even if the target directory
                                 already exists.

Run "dart help" to see global options.
```

↑からも分かる通り、作成できるプロジェクトテンプレートの種類としては

- console
- package
- server-shelf
- web

があるみたいです。

また `--no-pub` でプロジェクト作成後の `pub get` を実行しないオプションもある様です。

## console

早速プロジェクトを作成してみます。 `-t` のデフォルトが `console` になっているので何も指定しないと `console` のプロジェクトが作成されます。

```bash
$ dart create -t console dart-console-sample
$ cd dart-console-sample
$ tree
.
├── CHANGELOG.md
├── README.md
├── analysis_options.yaml
├── bin
│   └── dart_console_sample.dart
├── lib
│   └── dart_console_sample.dart
├── pubspec.lock
├── pubspec.yaml
└── test
    └── dart_console_sample_test.dart
```

コマンドラインツールを作成する為のプロジェクトテンプレートになっています。

作成された `bin/dart_console_sample.dart` と `lib/dart_console_sample.dart` `pubspec.yaml` の中身はそれぞれ以下の様になっています。

- `bin/dart_console_sample.dart`

    ```dart
    import 'package:dart_console_sample/dart_console_sample.dart' as dart_console_sample;
    
    void main(List<String> arguments) {
      print('Hello world: ${dart_console_sample.calculate()}!');
    }
    ```

- `lib/dart_console_sample.dart`

    ```dart
    int calculate() {
      return 6 * 7;
    }
    ```

- `pubspec.yaml`

    ```yaml
    name: dart_console_sample
    description: A sample command-line application.
    version: 1.0.0
    # repository: https://github.com/my_org/my_repo
    
    environment:
      sdk: ^3.1.5
    
    # Add regular dependencies here.
    dependencies:
      # path: ^1.8.0
    
    dev_dependencies:
      lints: ^2.0.0
      test: ^1.21.0
    ```

実行するには `dart run` を実行します。

```bash
$ dart run                                  
Building package executable... 
Built dart_console_sample:dart_console_sample.
Hello world: 42!
```

さらに実行可能なバイナリファイルを作成するには以下のコマンドを実行します。

```bash
dart compile exe bin/dart_console_sample.dart
```

すると `bin/dart_console_sample.exe` ファイルが作成されます。単独で実行可能です。

```bash
$ ./bin/dart_console_sample.exe 
Hello world: 42!
```

また補足ですが、他にも以下の出力形式にコンパイルできます。

- aot-snapshot
  - dart runtimeは含まない、アプリをコンパイルする現在のアーキテクチャに固有の出力ファイルを生成する
  - Flutterのreleaseビルドの形式
- jit-snapshot
  - 解析されたすべてのクラスと、プログラムのトレーニング実行中に生成されるコンパイルされたコードが含まれる形式
- kernel
  - [Kernel AST](https://github.com/dart-lang/sdk/blob/main/pkg/kernel/README.md) 形式のバイナリを出力する
- js
  - Dartコードを配備可能なJavaScriptにコンパイル
  - 出力先を何も指定しないと直下に `out.js`, `out.js.deps`, `out.js.map` が作成される

## package

次に `package` テンプレートを試してみたいと思います。

```bash
$ dart create -t package dart-package-sample
$ cd dart-package-sample
$ tree
.
├── CHANGELOG.md
├── README.md
├── analysis_options.yaml
├── example
│   └── dart_package_sample_example.dart
├── lib
│   ├── dart_package_sample.dart
│   └── src
│       └── dart_package_sample_base.dart
├── pubspec.lock
├── pubspec.yaml
└── test
    └── dart_package_sample_test.dart
```

[pub.dev](https://pub.dev/) で公開されている様なライブラリを作成する為のテンプレートになります。

作成された主なファイルは以下になります。

- `lib/src/dart_package_sample_base.dart`

    ```dart
    // TODO: Put public facing types in this file.
    
    /// Checks if you are awesome. Spoiler: you are.
    class Awesome {
      bool get isAwesome => true;
    }
    ```

- `lib/dart_package_sample.dart`

    ```dart
    /// Support for doing something awesome.
    ///
    /// More dartdocs go here.
    library;
    
    export 'src/dart_package_sample_base.dart';
    
    // TODO: Export any libraries intended for clients of this package.
    ```

- `example/dart_package_sample_example.dart`

    ```dart
    import 'package:dart_package_sample/dart_package_sample.dart';
    
    void main() {
      var awesome = Awesome();
      print('awesome: ${awesome.isAwesome}');
    }
    ```

- `pubspec.yaml`

    ```yaml
    name: dart_package_sample
    description: A starting point for Dart libraries or applications.
    version: 1.0.0
    # repository: https://github.com/my_org/my_repo
    
    environment:
      sdk: ^3.1.5
    
    # Add regular dependencies here.
    dependencies:
      # path: ^1.8.0
    
    dev_dependencies:
      lints: ^2.0.0
      test: ^1.21.0
    ```

## server-shelf

どんなテンプレートなのかさっぱりだったので実際にプロジェクト作成して調べてみました。

どうやら  [shelf](https://pub.dev/packages/shelf) というweb server middleware を使用したwebアプリケーションの雛形を作れるみたいです。

```bash
$ dart create -t server-shelf dart-shelf-sample
$ cd dart-shelf-sample
$ tree
.
├── CHANGELOG.md
├── Dockerfile
├── README.md
├── analysis_options.yaml
├── bin
│   └── server.dart
├── pubspec.lock
├── pubspec.yaml
└── test
    └── server_test.dart
```

実際にプロジェクトを作成してみると上記の様なディレクトリ構成で作成され、デプロイ用(?)の `Dockerfile` も作成してくれていました。この時の`Dockerfile` の中身は以下の様になっていました。

```docker
# Use latest stable channel SDK.
FROM dart:stable AS build

# Resolve app dependencies.
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

# Copy app source code (except anything in .dockerignore) and AOT compile app.
COPY . .
RUN dart compile exe bin/server.dart -o bin/server

# Build minimal serving image from AOT-compiled `/server`
# and the pre-built AOT-runtime in the `/runtime/` directory of the base image.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/

# Start server.
EXPOSE 8080
CMD ["/app/bin/server"]
```

`bin/server.dart` の中身は以下

```dart
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

// Configure routes.
final _router = Router()
  ..get('/', _rootHandler)
  ..get('/echo/<message>', _echoHandler);

Response _rootHandler(Request req) {
  return Response.ok('Hello, World!\n');
}

Response _echoHandler(Request request) {
  final message = request.params['message'];
  return Response.ok('$message\n');
}

void main(List<String> args) async {
  // Use any available host or container IP (usually `0.0.0.0`).
  final ip = InternetAddress.anyIPv4;

  // Configure a pipeline that logs requests.
  final handler = Pipeline().addMiddleware(logRequests()).addHandler(_router);

  // For running in containers, we respect the PORT environment variable.
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await serve(handler, ip, port);
  print('Server listening on port ${server.port}');
}
```

パッと見で何となく処理のイメージがつく感じですね 👀

`pubspec.yaml` は以下の内容になります。

```yaml
name: dart_shelf_sample
description: A server app using the shelf package and Docker.
version: 1.0.0
# repository: https://github.com/my_org/my_repo

environment:
  sdk: ^3.1.5

dependencies:
  args: ^2.3.0
  shelf: ^1.4.0
  shelf_router: ^1.1.0

dev_dependencies:
  http: ^0.13.0
  lints: ^2.0.0
  test: ^1.21.0
```

手元で実行する場合は、↓の通り実行し [http://0.0.0.0:8080](http://0.0.0.0:8080/) や [http://0.0.0.0:8080/echo/I_love_Dart](http://0.0.0.0:8080/echo/I_love_Dart) にアクセスすると挙動が確認できます。

```bash
$ dart run bin/server.dart
Server listening on port 8080
```

Docker環境で実行する場合は↓の様に実行します。

```bash
$ docker build . -t myserver
$ docker run -it -p 8080:8080 myserver
Server listening on port 8080
```

## web

最後に `web` テンプレートを試してみたいと思います。

```bash
$ dart create -t web dart-web-sample
$ cd dart-web-sample
$ tree
.
├── CHANGELOG.md
├── README.md
├── analysis_options.yaml
├── pubspec.lock
├── pubspec.yaml
└── web
    ├── index.html
    ├── main.dart
```

作成された `web/index.html` と `web/main.dart` を見ると以下の様になっていました。

- `web/index.html`

    ```html
    <!DOCTYPE html>
    
    <html>
    <head>
        <meta charset="utf-8">
        <meta http-equiv="X-UA-Compatible" content="IE=edge">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <meta name="scaffolded-by" content="https://github.com/dart-lang/sdk">
        <title>dart_web_sample</title>
        <link rel="stylesheet" href="styles.css">
        <script defer src="main.dart.js"></script>
    </head>
    
    <body>
    
      <div id="output"></div>
    
    </body>
    </html>
    ```

- `web/main.dart`

    ```dart
    import 'dart:html';
    
    void main() {
      querySelector('#output')?.text = 'Your Dart app is running.';
    }
    ```

↑を見る限り `web/main.dart` が `main.dart.js` にコンパイルされて `web/index.html` から読み込まれていそうです。

起動させるには [webdev](https://pub.dev/packages/webdev) というパッケージが必要な様です。

パッケージの説明には

> Dart を使ってウェブアプリケーションを開発し、デプロイするためのコマンドラインツール。

という風になっています。webdevに必要なパッケージの `build_runner` と `build_web_compilers` は既に `pubspec.yaml` に記述されていました。

早速 webdevをインストールして起動させてみたいと思います。

```bash
$ dart pub global activate webdev
$ webdev serve
webdev serve
[INFO] Building new asset graph completed, took 686ms
[INFO] Checking for unexpected pre-existing outputs. completed, took 0ms
[INFO] Serving `web` on http://127.0.0.1:8080
[INFO] Running build completed, took 1.7s
[INFO] Caching finalized dependency graph completed, took 87ms
[INFO] Succeeded after 1.7s with 15 outputs (1758 actions)
```

起動した状態で [http://127.0.0.1:8080](http://127.0.0.1:8080/) にアクセスすると想像通り `Your Dart app is running.` が表示されていました。

ちなみに `pubspec.yaml` は以下の内容になります。

```yaml
name: dart_web_sample
description: An absolute bare-bones web app.
version: 1.0.0
# repository: https://github.com/my_org/my_repo

environment:
  sdk: ^3.1.5

# Add regular dependencies here.
dependencies:
  # path: ^1.8.0

dev_dependencies:
  build_runner: ^2.4.0
  build_web_compilers: ^4.0.0
  lints: ^2.0.0
```

# 参考URL

[Dartで作るコマンドラインツール](https://zenn.dev/0maru/articles/c3acebaa727c7d)