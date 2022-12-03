---
title: "Inside Flutter Hooks"
emoji: "👀"
type: "tech"
topics:
  - "flutter"
  - "android"
  - "ios"
  - "dart"
  - "hook"
published: true
published_at: "2020-09-24 15:22"
---

## 概要
Flutter Hooksを使う機会があり、すごい便利だなと思っていたのですが、
内部的にどんな風に実装されているのか掘り下げてみようかと思い、今回色々調べてみました。
(何か間違っていたりしたらコメントいただけると嬉しいです :bow: )

## Flutter Hooks とは?

[React hooks](https://ja.reactjs.org/docs/hooks-intro.html)をFlutterで実装したものになります。

![image](https://storage.googleapis.com/zenn-user-upload/8271jd1ayi6exounjkb1fubb1qiu)
https://github.com/rrousselGit/flutter_hooks


作者は[Provider](https://github.com/rrousselGit/provider)等でおなじみのRemiさんです。

## サンプルの実行環境

flutter: v1.20.3
flutter_hooks: 0.14.0

## Flutter Hooksの基本的な仕組み

### `useMemoized` を掘り下げる
一番シンプルな `useMemoized` というhookを例にFlutter Hooksがどのような仕組みになっているのか追ってみたいと思います。

### そもそも `useMemoized` とは?
`useMemoized` は何回ビルドが走っても初期値をキャッシュしてくれるhookです。

↓簡単なサンプルとして現在時刻を `useMemoized` でキャッシュし、`Floating Action Button` をタップする度に
カウンターが増えて再ビルドが走るようなサンプルを作成してみました。

```dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final DateTime now = useMemoized(() => DateTime.now()); // 初期値として現在日時を保存
    final ValueNotifier<int> counter = useState<int>(0);
    return MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  now.toString(),
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                ),
                Text(
                  counter.value.toString(),
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                )
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => counter.value++, // カウンターが増えWidgetのビルドが走る
            child: Icon(Icons.add),
          ),
        ));
  }
}
```
実行結果
![](https://storage.googleapis.com/zenn-user-upload/bpqnudds3cagkvi1bj8rhm2at7x4 =250x)


↑ counterの値が更新されても初期値として設定した現在日時の値は変更されていないのが分かるかと思います。
(2020-09-11 11:21:40.... の箇所)

### `useMemoized` の実装は?
[こちら](https://github.com/rrousselGit/flutter_hooks/blob/61183617aaba4d33cf3061cab0190cb1618092fd/lib/src/primitives.dart#L9) で実装されています。以下に関連箇所だけ抜き出しました。

```dart
T useMemoized<T>(T Function() valueBuilder,
    [List<Object> keys = const <dynamic>[]]) {
  return use(_MemoizedHook(
    valueBuilder,
    keys: keys,
  ));
}

class _MemoizedHook<T> extends Hook<T> {
  const _MemoizedHook(
    this.valueBuilder, {
    List<Object> keys = const <dynamic>[],
  })  : assert(valueBuilder != null, 'valueBuilder cannot be null'),
        assert(keys != null, 'keys cannot be null'),
        super(keys: keys);

  final T Function() valueBuilder;

  @override
  _MemoizedHookState<T> createState() => _MemoizedHookState<T>();
}

class _MemoizedHookState<T> extends HookState<T, _MemoizedHook<T>> {
  T value;

  @override
  void initHook() {
    super.initHook();
    value = hook.valueBuilder();
  }

  @override
  T build(BuildContext context) {
    return value;
  }

  @override
  String get debugLabel => 'useMemoized<$T>';
}
```
より詳細に見ていこうと思います。:eyes:

### `useメソッド`
先ずは `useMemoized ` 内で使用されている `use(_MemoizedHook(...` の `use`メソッド を掘り下げてみたいと思います。
この `use`メソッド は [flutter_hooks/lib/src/framework.dart](https://github.com/rrousselGit/flutter_hooks/blob/61183617aaba4d33cf3061cab0190cb1618092fd/lib/src/framework.dart#L19) で以下の様に実装されています。

```dart
R use<R>(Hook<R> hook) => Hook.use(hook);
```
`Hook` というクラスのstatic メソッド  `use` に引数のhook(ここでは_MemoizedHook)を渡して呼んでいます。
ここで `Hook` というクラスが出てきました。今度はこの `Hook` に着目したいと思います。

### `Hookクラス`
Hookクラスは[こちら](https://github.com/rrousselGit/flutter_hooks/blob/61183617aaba4d33cf3061cab0190cb1618092fd/lib/src/framework.dart#L130)に実装されています。
以下に要約したものを抜き出してみました。

```dart
@immutable
abstract class Hook<R> with Diagnosticable {
  const Hook({this.keys});

  @Deprecated('Use `use` instead of `Hook.use`')
  static R use<R>(Hook<R> hook) {
    assert(HookElement._currentHookElement != null, '''
Hooks can only be called from the build method of a widget that mix-in `Hooks`.
Hooks should only be called within the build method of a widget.
Calling them outside of build method leads to an unstable state and is therefore prohibited.
''');
    return HookElement._currentHookElement._use(hook);
  }

  final List<Object> keys;

  @protected
  HookState<R, Hook<R>> createState();
}
```

先程出てきた `Hook.use` に着目したいと思います。
`@Deprecated` となっていて直接 `Hook.use` は呼ばずに先程の `useメソッド` を呼ぶようにとなっています。

ここでは `HookElement._currentHookElement._use(hook)` が呼ばれており、
`HookElement._currentHookElement` は後でも出てきますが [こちら](https://github.com/rrousselGit/flutter_hooks/blob/61183617aaba4d33cf3061cab0190cb1618092fd/lib/src/framework.dart#L361)にstatic変数として定義されています。
 `HookElement._currentHookElement._use` は別途掘り下げるとして  `createState` で生成される `HookState` を見てみます。 

### `HookStateクラス`
[こちら](https://github.com/rrousselGit/flutter_hooks/blob/61183617aaba4d33cf3061cab0190cb1618092fd/lib/src/framework.dart#L206)に実装されています。こちらも要約したものを以下に抜き出してみました。

```dart
abstract class HookState<R, T extends Hook<R>> with Diagnosticable {
  @protected
  BuildContext get context => _element;
  HookElement _element;

  T get hook => _hook;
  T _hook;

  @protected
  void initHook() {}

  @protected
  void dispose() {}

  @protected
  R build(BuildContext context);

  @protected
  void didUpdateHook(T oldHook) {}

  void deactivate() {}
  void reassemble() {}

  @protected
  void setState(VoidCallback fn) {
    fn();
    _element
      .._isOptionalRebuild = false
      ..markNeedsBuild();
  }
}
```

こうして見ると `Hook` と `HookState` の関係が `StatefulWidget` と `State` の関係に似てますね :eyes:

`HookState` 内に先程出てきた `HookElement` を保持し、`BuildContext` としてgetできるようにしています。
後で出てきますが、`HookElement` は `ComponentElement` をimplementしているので `BuildContext` として扱う事ができます。
詳しくはこちらを参照して下さい。
[FlutterのBuildContextとは何か - Qiita](https://qiita.com/ko2ic/items/f7bf98b4a30049027470)

### `HookElement mixin `
[こちら](https://github.com/rrousselGit/flutter_hooks/blob/61183617aaba4d33cf3061cab0190cb1618092fd/lib/src/framework.dart#L360)に実装されています。こちらも要約して抜き出してみました。
`HookElement` の `use` メソッドでの処理がFlutter Hooksのキモとなる処理になってきます。

```dart
mixin HookElement on ComponentElement {
  static HookElement _currentHookElement;

  _Entry<HookState> _currentHookState;
  final LinkedList<_Entry<HookState>> _hooks = LinkedList();
  LinkedList<_Entry<bool Function()>> _shouldRebuildQueue;
  LinkedList<_Entry<HookState>> _needDispose;
  bool _isOptionalRebuild = false;
  Widget _buildCache;

  @override
  Widget build() {
    // 色々な前処理 ...
    _currentHookState = _hooks.isEmpty ? null : _hooks.first; // ①
    HookElement._currentHookElement = this; // ②
    try {
      _buildCache = super.build();
    } finally {
      // 後処理 ....
    }
    return _buildCache;
  }

  R _use<R>(Hook<R> hook) {
    if (_currentHookState == null) {
      _appendHook(hook);
    } else if (hook.runtimeType != _currentHookState.value.hook.runtimeType) { // ③
      final previousHookType = _currentHookState.value.hook.runtimeType;
      _unmountAllRemainingHooks();
      if (kDebugMode && _debugDidReassemble) {
        _appendHook(hook);
      } else {
        throw StateError('''
Type mismatch between hooks:
- previous hook: $previousHookType
- new hook: ${hook.runtimeType}
''');
      }
    } else if (hook != _currentHookState.value.hook) {
      final previousHook = _currentHookState.value.hook;
      if (Hook.shouldPreserveState(previousHook, hook)) { // ④
        _currentHookState.value
          .._hook = hook
          ..didUpdateHook(previousHook);
      } else {
        _needDispose ??= LinkedList();
        _needDispose.add(_Entry(_currentHookState.value));
        _currentHookState.value = _createHookState<R>(hook);
      }
    }

    final result = _currentHookState.value.build(this) as R;
    _currentHookState = _currentHookState.next; // ⑤
    return result;
  }
}
```
先程 `HookState` で出てきた `HookElement._currentHookElement` が定義されています。

#### 大まかな処理の流れ

- _currentHookState
    - `HookState` の LinkedListになっておりビルド中に useXXX で呼ばれた際の各HookStateの一覧を**呼ばれた順で**保持しています

- build メソッド
    - ① : 前回Widgetのビルドが走った際の `HookState`のLinkedList のキャッシュがあれば `_currentHookState` にセットしています
    - ② : staticな領域に現在build中のHookElementをセットしています

    `HookWidget` や `StatefulHookWidget` クラスを使ったWidgetのビルドでは内部的に `HookElement` を使用しているので `HookElement` の `build()` メソッドが呼ばれます。

- use メソッド
    - ③ : 前回ビルドした時のHookと今回ビルド中のHookの `runtimeType` が異なっている場合
        - _currentHookStateに格納されているHookStateをすべてクリアします
        - Debug中の場合(開発しててuseXXXを変更した等)今回Hookを新たに格納します
    - ④ : 前回ビルド時のHookと異なるオブジェクトの場合 `shouldPreserveState` メソッドでKeyが前回と異なっているかチェックを行います
        - 異なっている場合
            - 一旦以前のHookStateは破棄して今回のHookStateに入れ替えます
        - 異なっていない場合
            - `HookState` の `didUpdateHook` が呼ばれます
    - ⑤ :  次に備えて、`_currentHookState.next` で次のHookStateにLinkedList内の位置を移動させています

LinkedListを使用して前回ビルドのHookStateと比較する処理は  flutter_hooksのREADMEにも載っていますが
[React hooks: not magic, just arrays | by Rudi Yardley | Medium](https://medium.com/@ryardley/react-hooks-not-magic-just-arrays-cd4f1857236e)
こちらを読むとさらに理解が深まりそうでした。

#### `useMemoized` に立ち返って

ここで  `useMemoized` 内で呼ばれていた `Hook.use` に立ち返ってみると `HookElement._currentHookElement._use(hook)` が呼ばれていました。

引数の `hook` は `_MemoizedHook` が設定され `use` メソッドが呼ばれることになります。
`_currentHookState` がnullの場合(初めてWidgetビルド中にuseXXXが呼ばれた場合)は `_appendHook` が呼ばれてます。
  `_appendHook` は何をしているかというと

```dart
extension on HookElement {
  HookState<R, Hook<R>> _createHookState<R>(Hook<R> hook) {
    assert(() {
      _debugIsInitHook = true;
      return true;
    }(), '');

    final state = hook.createState()
      .._element = this
      .._hook = hook
      ..initHook();

    assert(() {
      _debugIsInitHook = false;
      return true;
    }(), '');

    return state;
  }

  void _appendHook<R>(Hook<R> hook) {
    final result = _createHookState<R>(hook);
    _currentHookState = _Entry(result);
    _hooks.add(_currentHookState);
  }
}
```
`Hookクラス`の `createState` を呼び出して `HookState` を作成し `_currentHookState` に設定しています。
上記であった前回ビルド時のHookStateと比較する等の処理が終わったあと以下の処理が行われます。

```dart
    final result = _currentHookState.value.build(this) as R;
    _currentHookState = _currentHookState.next;
    return result;
```
ここで `HookState` の buildメソッドを呼び出して戻りuseメソッドの戻り値として返しています。
`useMemoized` の場合だと `_MemoizedHookState ` の buildが呼ばれることになり、
`_MemoizedHookState ` の buildは単に保存した値を返しているだけなので、いくらWidgetのビルドが走っても
更新されない保存された値を返し続けるという仕組みになっているようです :sparkles: 

```dart
  @override
  T build(BuildContext context) {
    return value;
  }
```

### `HookWidget`
最後にhookを使う側で必要な `HookWidget` クラスを見てみたいと思います。

```dart
abstract class HookWidget extends StatelessWidget {
  const HookWidget({Key key}) : super(key: key);

  @override
  _StatelessHookElement createElement() => _StatelessHookElement(this);
}

class _StatelessHookElement extends StatelessElement with HookElement {
  _StatelessHookElement(HookWidget hooks) : super(hooks);
}
```
すごいシンプルで、`StatelessWidget` クラスを継承し、Elementを生成する際に
`HookElement` を実装した `_StatelessHookElement` を返すようになっています。

また、`StatefulWidget` 版も用意されている様でした。

```dart
abstract class StatefulHookWidget extends StatefulWidget {
  const StatefulHookWidget({Key key}) : super(key: key);

  @override
  _StatefulHookElement createElement() => _StatefulHookElement(this);
}

class _StatefulHookElement extends StatefulElement with HookElement {
  _StatefulHookElement(StatefulHookWidget hooks) : super(hooks);
}

``` 

ここまで仕組みがどうなっているのか超ざっくり説明しました。

### 主な登場人物とざっくり相関図
これまでで登場してきたクラスやmixinを相関図にしてみました。

- Hook
- HookElement
- HookState
- HookWidget
- StatefulHookWidget (※今回は省いています)

![](https://storage.googleapis.com/zenn-user-upload/xzfa1g4zohz0o25wpytbsv7ahtc2 =600x)


※ 間違っていたらご指摘いただけると嬉しいです :bow:

## 他のhooks達
ここまでで何となくでも仕組みが理解できたので、他のhooksも見てみたいと思います。

### `useContext`
[実装はこちら](https://github.com/rrousselGit/flutter_hooks/blob/61183617aaba4d33cf3061cab0190cb1618092fd/lib/src/framework.dart#L607)
これは至ってシンプルで以下の様に実装されています。

```dart
BuildContext useContext() {
  assert(
    HookElement._currentHookElement != null,
    '`useContext` can only be called from the build method of HookWidget',
  );
  return HookElement._currentHookElement;
}
```
実装をみるとなぜbuild中じゃないと呼び出せないのか分かりますね  :eyes:
ちなみに `HookElement._currentHookElement` が null になるタイミングはWidgetのビルドが終わったタイミングになります。

### `useEffect`
[実装はこちら](https://github.com/rrousselGit/flutter_hooks/blob/61183617aaba4d33cf3061cab0190cb1618092fd/lib/src/primitives.dart#L146)

```dart
void useEffect(Dispose Function() effect, [List<Object> keys]) {
  use(_EffectHook(effect, keys));
}

class _EffectHook extends Hook<void> {
  const _EffectHook(this.effect, [List<Object> keys])
      : assert(effect != null, 'effect cannot be null'),
        super(keys: keys);

  final Dispose Function() effect;

  @override
  _EffectHookState createState() => _EffectHookState();
}

class _EffectHookState extends HookState<void, _EffectHook> {
  Dispose disposer;

  @override
  void initHook() {
    super.initHook();
    scheduleEffect();
  }

  @override
  void didUpdateHook(_EffectHook oldHook) {
    super.didUpdateHook(oldHook);

    if (hook.keys == null) {
      if (disposer != null) {
        disposer();
      }
      scheduleEffect();
    }
  }

  @override
  void build(BuildContext context) {}

  @override
  void dispose() {
    if (disposer != null) {
      disposer();
    }
  }

  void scheduleEffect() {
    disposer = hook.effect();
  }

  @override
  String get debugLabel => 'useEffect';

  @override
  bool get debugSkipValue => true;
}
```

使い方としては `useEffect` 第一引数で渡された処理が初回呼ばれて、以降は第二引数のKeyに変更が無い限り
処理が呼ばれる事はありません。

```dart
    useEffect(() {
      print('useEffect');
      return () => print('dispose');
    }, const []);
```
↑の例だと第二引数のKeyに `const []` を指定しているので初回だけしか `print('useEffect');` は呼ばれません。
また第一引数の戻り値として終了処理を `Function()` として返せるのでもう一度処理が呼ばれる前にクリアさせたい等に使えそうです。

Keyが変更されるサンプルとして `useMemoized` のサンプルに `useEffect` を呼ぶ処理を追加してみました。

```dart
// ... 省略
class MyApp extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final DateTime now = useMemoized(() => DateTime.now());
    final ValueNotifier<int> counter = useState<int>(0);
    // ☆ここから追加
    useEffect(() {
      print('useEffect');
      return () => print('dispose');
    }, [counter.value]);
// ... 省略
```
↑のサンプルを実行し + ボタンをタップすると `print('useEffect');` と `print('dispose');` が呼ばれるのが分かるかと思います。
![](https://storage.googleapis.com/zenn-user-upload/08n3vyp8ms8vrz8wzpmj8uge58ak =400x)


#### `useEffect`のしくみ

初回呼ばれる `initHook` 内で `scheduleEffect` メソッドを呼び出しています。
 `scheduleEffect` メソッドがどうなっているかというと

```dart
  void scheduleEffect() {
    disposer = hook.effect();
  }
```
`useEffect` の第一引数で渡された `Function()` を 呼び出し戻り値の dispose を内部で保存しています。
disposeはここでは `typedef Dispose = void Function();` として定義されています。
このタイミングで初回の処理を呼び出しています。

次に第二引数のKeyが変更された時点の処理を見てみたいと思います。

```dart
    } else if (hook != _currentHookState.value.hook) {
      final previousHook = _currentHookState.value.hook;
      if (Hook.shouldPreserveState(previousHook, hook)) {
        _currentHookState.value
          .._hook = hook
          ..didUpdateHook(previousHook);
      } else {
        _needDispose ??= LinkedList();
        _needDispose.add(_Entry(_currentHookState.value));
        _currentHookState.value = _createHookState<R>(hook);
      }
    }
```
既に説明した通り、`HookElement` の `use` メソッド内でKeyが変更されたかの判定を `shouldPreserveState` で行っており
Keyが変更されている場合、新たにHookStateを作り直しています。
作り直す際に `initHook` が呼ばれ内部で `scheduleEffect` を呼んでいます。
破棄された方のHookStateはbuildの最後で `dispose` が呼ばれ、内部で保持していた `disposer()` を呼び出しています。

### `useState`

[実装はこちら](https://github.com/rrousselGit/flutter_hooks/blob/61183617aaba4d33cf3061cab0190cb1618092fd/lib/src/primitives.dart#L231)

```dart
ValueNotifier<T> useState<T>([T initialData]) {
  return use(_StateHook(initialData: initialData));
}

class _StateHook<T> extends Hook<ValueNotifier<T>> {
  const _StateHook({this.initialData});

  final T initialData;

  @override
  _StateHookState<T> createState() => _StateHookState();
}

class _StateHookState<T> extends HookState<ValueNotifier<T>, _StateHook<T>> {
  ValueNotifier<T> _state;

  @override
  void initHook() {
    super.initHook();
    _state = ValueNotifier(hook.initialData)..addListener(_listener);
  }

  @override
  void dispose() {
    _state.dispose();
  }

  @override
  ValueNotifier<T> build(BuildContext context) {
    return _state;
  }

  void _listener() {
    setState(() {});
  }

  @override
  Object get debugValue => _state.value;

  @override
  String get debugLabel => 'useState<$T>';
}
```

こちらは既に `useMemoized` のサンプルで使ってましたが、こちらは `ValueNotifier` をラップし
扱いやすくしてくれているhooksになります。

#### `useState`のしくみ

こちらはシンプルで `initHook` 時に `ValueNotifier` を生成し、build時には生成した  `ValueNotifier` を返しています。

## まとめ

基本的なhooksの仕組みを何となくでも把握しとけば、他のhooksもソースコードを読むことで
ある程度理解できるようになりました :sparkles: 
今回のように一番シンプルなものから掘り下げていくのは余分なInputが少ない分理解しやすいですね。

内部的な処理が分かっていれば、useContext をWidgetのビルドタイミング以外で使用したらダメだとか
事前に分かるので、広範囲でお世話になるライブラリ等は事前に内部がどんな風になっているのか把握しておくと、
トータル的にはハマる時間が無くなってスムーズかもしれません :sparkles: 

また次も機会があれば何か掘り下げようかと思います。