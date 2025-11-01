---
title: "WebGPU入門"
emoji: "🌊"
type: "tech" # tech: 技術記事 / idea: アイデア
topics:
  - "webgpu"
  - "shader"
  - "wgsl"
published: true
---
# 概要

今回はWebGPUに関して、以下リンクのドキュメントに沿って自分なりにキャッチアップした際のメモになります。

https://developer.mozilla.org/ja/docs/Web/API/WebGPU_API

# 動作環境

- MBA M3 Sequoia 15.6.1
- Chrome バージョン 141.0.7390.123（Official Build） （arm64）

# WebGPUとは…?

> WebGLの後継で、最近の GPU API と互換性があり、汎用 GPU 計算に対応し、操作を速くし、さらに高度な GPU の機能へのアクセスを可能にします

具体的にどんな事ができるのかは以下でWebGPUのサンプルが色々公開されていて、実際に動かして試す事ができます！ (有益なサイトありがとうございます ✨)

https://compute.toys/

## WebGLとは…?

 [OpenGL ES 2.0](https://registry.khronos.org/OpenGL-Refpages/es2.0/) グラフィックライブラリーの JavaScript への移植。GPUでの計算結果を [`<canvas>`](https://developer.mozilla.org/ja/docs/Web/HTML/Reference/Elements/canvas) 要素内に描画できる。シェーダーのコードを書く場合は  [GLSL](https://www.khronos.org/opengl/wiki/Core_Language_(GLSL)) で書く必要がある。

WebGLの問題点

- 新世代のネイティブ GPU API が登場
  - [Direct3D 12](https://learn.microsoft.com/ja-jp/windows/win32/direct3d12/direct3d-12-graphics), [Metal](https://developer.apple.com/metal/), [Vulkan](https://www.vulkan.org/)
  - OpenGL のアップデートはもう計画されておらず、WebGL も同様なので上記の新しいGPU API が使えない
- 汎用 GPPU (GPGPU) 計算をあまり上手く扱えない
- 3D グラフィックアプリケーションの負荷が今後高くなっていく

WebGPUはこれらの問題点を改善したもの。

# 一般的なモデル(1デバイス1GPU)の構成図

![image1.png](/images/c7f69fbdfe84ed/image1.png =400x)

※ MDNドキュメントより

上の図の「Native GPU API / Driver」部分が例えばmacOSで言うとMetalに当たる。WebGPUのAdapterが Native GPU API とのやり取りを行う。

# デバイスへのアクセス

WebGPUでは論理デバイスは **[`GPUDevice`](https://developer.mozilla.org/en-US/docs/Web/API/GPUDevice)** オブジェクトのインスタンスで表されます。論理デバイスにアクセスするには以下の様に書きます。

```jsx
async function init() {
  if (!navigator.gpu) {
    throw Error("WebGPU に対応していません。");
  }

  const adapter = await navigator.gpu.requestAdapter();
  if (!adapter) {
    throw Error("WebGPU アダプターの要求に失敗しました。");
  }

  const device = await adapter.requestDevice();
  console.log(device);
}
```

これを実際に以下 `index.html` を作成して試してみました。

@[stackblitz](https://stackblitz.com/edit/stackblitz-starters-f9jkokf9?embed=1&file=index.html)

これを実行すると手元のPCだと以下の結果になりました。

```text
--- WebGPU 初期化開始 ---
navigator.gpu が見つかりました。
GPUAdapter を取得しました。利用可能な機能数: 18
GPUDevice を取得しました。
サマリ: {
  "limits": {
    "maxTextureDimension2D": 8192,
    "maxBindGroups": 4,
    "maxComputeWorkgroupSizeX": 256,
    "maxComputeWorkgroupSizeY": 256,
    "maxComputeWorkgroupSizeZ": 64
  },
  "supportedFeaturesCount": 1
}
--- 初期化完了 ---
```

# パイプラインとシェーダー: WebGPU アプリケーションの構造

パイプライン: プログラマブルなステージが入る論理的な構造。WebGPUでは以下の 2 種類のパイプラインを扱うことができます。

1. レンダーパイプライン
    - canvas要素やオフスクリーン(一旦テクスチャに描いて後で利用する)にグラフィックをレンダリングする
    - プログラマブルなステージは以下の2つ
        1. **バーテックスステージ**: 形を決める
        2. **フラグメントステージ**: 色を決める
2. コンピュートパイプライン
    - 一般の計算用途で、データを受け取り、指定の数のワークグループで並列計算を行い、結果を 1 個以上のバッファーで返す

プログラマブルなステージでは [WebGPU Shader Language](https://gpuweb.github.io/gpuweb/wgsl/) (WGSL) と呼ばれる Rust 風の低レベルの言語で実装します。

## レンダーパイプラインの基礎

以下の様な青の背景に1つの三角形が表示されるレンダーパイプラインの簡単なサンプルを試してみます。

![image2.png](/images/c7f69fbdfe84ed/image2.png =500x)

https://mdn.github.io/dom-examples/webgpu-render-demo/

こちらで使うシェーダーコードは以下になります。

```jsx
const shaders = `
struct VertexOut {
  @builtin(position) position : vec4f,
  @location(0) color : vec4f
}

@vertex
fn vertex_main(@location(0) position: vec4f,
               @location(1) color: vec4f) -> VertexOut
{
  var output : VertexOut;
  output.position = position;
  output.color = color;
  return output;
}

@fragment
fn fragment_main(fragData: VertexOut) -> @location(0) vec4f
{
  return fragData.color;
}
`;
```

上記のシェーダーで プログラマブルなステージ の

- バーテックスステージ: `@vertex` が付いている箇所
- フラグメントステージ: `@fragment` が付いている箇所

にあたります。早速こちらを動かしてみます。

@[stackblitz](https://stackblitz.com/edit/stackblitz-starters-b5yqbfpx?embed=1&file=index.html&hideExplorer=1)

エラーがなければ三角形が表示されているかと思います。

### シェーダーモジュールの利用

シェーダーコードをWebGPUで使用する場合、以下の様に[`GPUDevice.createShaderModule()`](https://developer.mozilla.org/en-US/docs/Web/API/GPUDevice/createShaderModule) を使用し [`GPUShaderModule`](https://developer.mozilla.org/en-US/docs/Web/API/GPUShaderModule) を取得する必要があります。

```jsx
const shaderModule = device.createShaderModule({
  code: shaders,
});
```

### キャンバスコンテキストの取得と設定

以下ではグラフィックのレンダリング先を `<canvas>` にする為、`<canvas>` 要素を取得し、`canvas.getContext("webgpu")` でGPU コンテキスト ([`GPUCanvasContext`](https://developer.mozilla.org/ja/docs/Web/API/GPUCanvasContext) のインスタンス) を受け取り、設定を行います。

```jsx
      const canvas = document.querySelector('#gpuCanvas');
      const context = canvas.getContext('webgpu');

      context.configure({
        device: device,
        format: navigator.gpu.getPreferredCanvasFormat(),
        alphaMode: 'premultiplied',
      });
```

`context.configure` のパラメータを見ていきます。

- device
  - **[`GPUDevice`](https://developer.mozilla.org/en-US/docs/Web/API/GPUDevice)** を渡します
- format
  - `getCurrentTexture()` が返すテクスチャの形式
  - `bgra8unorm`・`rgba8unorm`・`rgba16float` のいずれか

    | フォーマット | 並び | 1chあたり | 合計/px | 値の型 | 主用途のイメージ |
    | --- | --- | --- | --- | --- | --- |
    | `bgra8unorm` | **B G R A** | 8bit | 32bit | **UNORM**（0–255を0.0–1.0に正規化） | 画面表示向け。プラットフォーム互換性が高く、`canvas`の既定に選ばれがち |
    | `rgba8unorm` | **R G B A** | 8bit | 32bit | **UNORM**（同上） | 一般的なテクスチャ/レンダーターゲット。UIや標準レンダリング |
    | `rgba16float` | **R G B A** | 16bit | 64bit | **半精度浮動小数（FP16）** | HDR、ポストプロセス、蓄積/計算バッファなど高ダイナミックレンジや精度が欲しい場面 |

- alphaMode
  - アルファ値が持つ効果を指定
  - `opaque` : アルファ値は無視される
  - `premultiplied` : 色の値はアルファ値を掛けた後の値になる

### 三角形データ

三角形の各頂点について 8 個のデータ (位置の X, Y, Z, W および色の R, G, B, A) が格納されています。

```jsx
      const vertices = new Float32Array([
        0.0, 0.6, 0, 1, 1, 0, 0, 1, -0.5, -0.6, 0, 1, 0, 1, 0, 1, 0.5, -0.6, 0,
        1, 0, 0, 1, 1,
      ]);
```

このデータを [`GPUBuffer`](https://developer.mozilla.org/en-US/docs/Web/API/GPUBuffer) に格納する必要があります。GPUBufferは [`GPUDevice.createBuffer()`](https://developer.mozilla.org/en-US/docs/Web/API/GPUDevice/createBuffer) で生成可能です。

```jsx
        const vertexBuffer = device.createBuffer({
          size: vertices.byteLength,
          usage: GPUBufferUsage.VERTEX | GPUBufferUsage.COPY_DST,
        });

        device.queue.writeBuffer(vertexBuffer, 0, vertices, 0, vertices.length);
```

`usage` に指定できる値は[こちら](https://developer.mozilla.org/en-US/docs/Web/API/GPUBuffer/usage#value)で確認できます。今回の場合だと `頂点データ` かつ `バッファは、コピー/書き込み操作の宛先として使用可能` という設定になっていそうです。

次に `writeBuffer` でデータを `GPUBuffer` に書き込んでいます。

### レンダーパイプラインの定義と生成

次にレンダリングに用いることができるパイプラインを実際に生成していきます。

```jsx
        const vertexBuffers = [
          {
            attributes: [
              {
                shaderLocation: 0, // 位置の X, Y, Z, W
                offset: 0,
                format: 'float32x4', // WGSL の vec4<f32> 型に対応
              },
              {
                shaderLocation: 1, // 色の R, G, B, A
                offset: 16,
                format: 'float32x4',
              },
            ],
            arrayStride: 32, // 各頂点を構成するバイト数
            stepMode: 'vertex',
          },
        ];

        const pipelineDescriptor = {
          vertex: {
            module: shaderModule,
            entryPoint: 'vertex_main',
            buffers: vertexBuffers,
          },
          fragment: {
            module: shaderModule,
            entryPoint: 'fragment_main',
            targets: [
              {
                format: navigator.gpu.getPreferredCanvasFormat(),
              },
            ],
          },
          primitive: {
            topology: 'triangle-list',
          },
          layout: 'auto',
        };

        const renderPipeline = device.createRenderPipeline(pipelineDescriptor);
```

`vertexBuffers` で三角形頂点データの属性を定義し `pipelineDescriptor` で バーテックスステージ のmoduleやシェーダー内のエントリーポイント、先ほど作成した`vertexBuffers` を指定してます。またフラグメントステージの方も同じくmoduleやエントリーポイント、formatを指定しています。

- [pipelineDescriptorのパラメータ](https://developer.mozilla.org/en-US/docs/Web/API/GPUDevice/createRenderPipeline#parameters)
  - `primitive`
    - パイプラインがその頂点入力からプリミティブをどのように構築し、ラスタライズするかを記述するオブジェクト
      - `topology`
        - 既に用意されている指定された頂点をどう構築するかの列挙値
          - **`line-list`**: 連続する2つの頂点のペアが、線プリミティブを定義
          - **`line-strip`**: 最初の頂点以降の各頂点が、それと前の頂点との間の線プリミティブを定義
          - **`point-list`**: 各頂点が、点プリミティブを定義
          - **`triangle-list`**: 連続する3つの頂点の組が、三角形プリミティブを定義
          - **`triangle-strip`**: 最初の2つの頂点以降の各頂点が、それと前の2つの頂点との間の三角形プリミティブを定義
        - 省略した場合、topology はデフォルトで **`triangle-list`** になる
      - `layout`
        - パイプライン実行中に使用されるすべてのGPUリソース（バッファ、テクスチャなど）のレイアウト（構造、目的、型）を定義
          - `GPUPipelineLayout` : GPUがパイプラインを事前に最も効率的に実行する方法を把握できるようにする
          - `"auto"` : シェーダーコードで定義されたバインディングに基づいて、パイプラインが暗黙的なバインドグループのレイアウトを生成するようにする
      - `vertex`
        - パイプラインの頂点シェーダーのエントリーポイントと、その入力バッファーレイアウトを記述する[オブジェクト](https://developer.mozilla.org/en-US/docs/Web/API/GPUDevice/createRenderPipeline#vertex_object_structure)
      - `fragment`
        - パイプラインのフラグメントシェーダーのエントリーポイントと、その出力カラーについて記述する[オブジェクト](https://developer.mozilla.org/en-US/docs/Web/API/GPUDevice/createRenderPipeline#fragment_object_structure)

最後に `createRenderPipeline` でレンダーパイプラインを生成しています。

### レンダリングパスの実行

準備ができたので`<canvas>` への描画を行っていきます。GPU に発行するコマンドをエンコードする為に [`GPUCommandEncoder`](https://developer.mozilla.org/en-US/docs/Web/API/GPUCommandEncoder) を生成する必要があります。

```jsx
const commandEncoder = device.createCommandEncoder();
```

次に [`GPUCommandEncoder.beginRenderPass()`](https://developer.mozilla.org/en-US/docs/Web/API/GPUCommandEncoder/beginRenderPass) を呼び出しレンダリングパスの実行を開始します。必須のプロパティである `renderPassDescriptor` を定義します。

```jsx
const clearColor = { r: 0.0, g: 0.5, b: 1.0, a: 1.0 };

const renderPassDescriptor = {
  colorAttachments: [
    {
      clearValue: clearColor,
      loadOp: "clear", // ロード後任意の描画を行う前に指定の色に「クリア」する
      storeOp: "store",
      view: context.getCurrentTexture().createView(), // <canvas> から新しいビューを生成
    },
  ],
};

const passEncoder = commandEncoder.beginRenderPass(renderPassDescriptor);
```

`colorAttachments` の構造を[こちら](https://developer.mozilla.org/en-US/docs/Web/API/GPUCommandEncoder/beginRenderPass#color_attachment_object_structure)で定義されています。

- clearValue
  - レンダリングパス実行前にビューテクスチャをクリアする色値
  - `loadOp` が `clear"` 設定されていない場合、この値は無視される
  - r、g、b、aの4つの色成分を表す小数点形式の配列またはオブジェクトを受け取る
- loadOp
  - ロード時の挙動を設定。以下の2つから選ぶ
      1. `clear`
          1. clearValueの色値でクリア
      2. `load`
          1. 既存の値をレンダーパスに読み込む
- storeOp
  - レンダーパス実行後にビューに対して行うストア操作
      1. `discard`
          1. レンダーパスの結果の値を破棄する
      2. `store`
          1. レンダーパスの結果の値を保存する
- view
  - 出力先

最後に描画を実行します。

```jsx
passEncoder.setPipeline(renderPipeline); // レンダリングパスで使用するパイプラインを指定
passEncoder.setVertexBuffer(0, vertexBuffer); // レンダリング用にパイプラインに渡すデータソースを設定
passEncoder.draw(3); // 描画を実行。頂点数の値を 3 を渡している
passEncoder.end(); // レンダーパスコマンドリストの終わりを示す

device.queue.submit([commandEncoder.finish()]); // GPU に送るためコマンドをキューに追加
```

これで一通りのベーシックなレンダーパイプラインの処理を見ました。ざっくり図解すると👇のような感じでしょうか。(間違っていたらご指摘頂けると助かります)

![image3.png](/images/c7f69fbdfe84ed/image3.png)

## コンピュートパイプラインの基本

以下のデモではGPU にある値を計算させた結果をコンソールログに出力しています。

https://mdn.github.io/dom-examples/webgpu-compute-demo/

![image4.png](/images/c7f69fbdfe84ed/image4.png =500x)

こちらで使うシェーダーコードは以下になります。

```jsx
const BUFFER_SIZE = 1000;

const shader = `
@group(0) @binding(0)
var<storage, read_write> output: array<f32>;

@compute @workgroup_size(64)
fn main(
  @builtin(global_invocation_id)
  global_id : vec3u,

  @builtin(local_invocation_id)
  local_id : vec3u,
) {
  // バッファーの範囲外にアクセスしないようにする
  if (global_id.x >= ${BUFFER_SIZE}) {
    return;
  }

  output[global_id.x] =
    f32(global_id.x) * 1000. + f32(local_id.x);
}
`;
```

レンダーパイプラインと違って今回は `@compute` ステージ1つしかありません。早速こちらを動かしてみます。

@[stackblitz](https://stackblitz.com/edit/stackblitz-starters-f6rfyxpf?embed=1&file=index.html)

計算結果が出力されているかと思います。

### データを扱うバッファの生成

データを扱うために以下の2種類の  [`GPUBuffer`](https://developer.mozilla.org/en-US/docs/Web/API/GPUBuffer) を生成します。

1. GPU での計算結果を高速で書き込む `output` バッファー
2. `output` の内容をコピーして JavaScript から値にアクセスできるようにマップできる `stagingBuffer`

```jsx
const output = device.createBuffer({
  size: BUFFER_SIZE,
  usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC,
});

const stagingBuffer = device.createBuffer({
  size: BUFFER_SIZE,
  usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST,
});
```

- `GPUBufferUsage.STORAGE`
  - GPUでのデータ格納領域として利用できる様にする
- `GPUBufferUsage.COPY_SRC`
  - このバッファは、コピー操作のソースとして使用可能
- `GPUBufferUsage.MAP_READ`
  - GPUのメモリ領域をCPUからアクセスできるようにする為にマッピング可能にする
- `GPUBufferUsage.COPY_DST`
  - コピー/書き込み操作の宛先として使用可能

### バインドグループレイアウトの生成

パイプラインの生成時、そのパイプラインで使用するバインドグループを指定する必要があります。その為にまず [`GPUBindGroupLayout`](https://developer.mozilla.org/en-US/docs/Web/API/GPUBindGroupLayout) を生成し、バインドグループが従うテンプレートとして用います。

```jsx
const bindGroupLayout = device.createBindGroupLayout({
  entries: [
    {
      binding: 0,
      visibility: GPUShaderStage.COMPUTE,
      buffer: {
        type: "storage",
      },
    },
  ],
});
```

上記の `binding: 0` がシェーダーコードの関連するバインディング番号 `@binding(0)` に結びつきます。他はパイプラインのコンピュートステージで使用でき、バッファーの目的が `storage` と定義された 1 個のメモリーバッファーにアクセスできるようにしています。

次に以下で [`GPUBindGroup`](https://developer.mozilla.org/en-US/docs/Web/API/GPUBindGroup) を生成します。

```jsx
const bindGroup = device.createBindGroup({
  layout: bindGroupLayout,
  entries: [
    {
      binding: 0,
      resource: {
        buffer: output,
      },
    },
  ],
});
```

### コンピュートパイプラインの生成

[`GPUDevice.createComputePipeline()`](https://developer.mozilla.org/en-US/docs/Web/API/GPUDevice/createComputePipeline) を用いてコンピュートパイプラインを生成します。レンダーパイプラインの生成と似た方法になっているかと思います。

```jsx
const computePipeline = device.createComputePipeline({
  layout: device.createPipelineLayout({
    bindGroupLayouts: [bindGroupLayout],
  }),
  compute: {
    module: shaderModule,
    entryPoint: "main",
  },
});
```

### コンピュートパスの実行

コンピュートパスの実行は以下の様になります。

```jsx
const commandEncoder = device.createCommandEncoder();
const passEncoder = commandEncoder.beginComputePass();

passEncoder.setPipeline(computePipeline);
passEncoder.setBindGroup(0, bindGroup);
passEncoder.dispatchWorkgroups(Math.ceil(BUFFER_SIZE / 64)); // 計算の実行に用いる GPU ワークグループの数を指定する

passEncoder.end();
```

[`GPUDevice: createCommandEncoder()`](https://developer.mozilla.org/en-US/docs/Web/API/GPUDevice/createCommandEncoder) で [`GPUCommandEncoder`](https://developer.mozilla.org/en-US/docs/Web/API/GPUCommandEncoder) (GPU に発行される GPU コマンドのシーケンスを収集するエンコーダ) を生成し、さらに [`GPUCommandEncoder.beginComputePass()`](https://developer.mozilla.org/en-US/docs/Web/API/GPUCommandEncoder/beginComputePass) によりパスエンコーダーを生成します。パスエンコーダーは `GPUCommandEncoder` の全体的なエンコード処理の一部を構成します。

[`GPUComputePassEncoder.dispatchWorkgroups()`](https://developer.mozilla.org/en-US/docs/Web/API/GPUComputePassEncoder/dispatchWorkgroups) では、計算の実行に用いる GPU ワークグループの数を指定します。

### 結果を JavaScript で読み取る

最後に `stagingBuffer` に書き出された計算結果を読み取れる様にして、結果を出力します。

```jsx
// 出力バッファーをステージングバッファーにコピーする
commandEncoder.copyBufferToBuffer(
  output,
  0, // コピー元のオフセット
  stagingBuffer,
  0, // コピー先のオフセット
  BUFFER_SIZE,
);

// コマンドバッファーの配列を実行用のコマンドキューに渡し、フレームを終える
device.queue.submit([commandEncoder.finish()]);

// JS に結果を読み戻すため、ステージングバッファーをマップする
await stagingBuffer.mapAsync(
  GPUMapMode.READ,
  0, // オフセット
  BUFFER_SIZE, // サイズ
);

const copyArrayBuffer = stagingBuffer.getMappedRange(0, BUFFER_SIZE);
const data = copyArrayBuffer.slice();
stagingBuffer.unmap();
console.log(new Float32Array(data));
```

コンピュートパイプラインの処理を見れたので、こちらもざっくり図解してみました。(間違っていたらご指摘頂けると助かります)

![image5.png](/images/c7f69fbdfe84ed/image5.png)

# まとめ

今回はWebGPUの雰囲気を掴む為、ドキュメントに沿って試してみました。登場人物(GPUDevice, GPUXXXX…)が多いので迷子になってしまいそうですが、流れを掴んでいればそこまで迷わなくなりそうかなと感じました。まだまだ試し甲斐がありそうなので色々トライしてみようと思います。