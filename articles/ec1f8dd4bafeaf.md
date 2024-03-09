---
title: "HealthKitキャッチアップ"
emoji: "🏥"
type: "tech" # tech: 技術記事 / idea: アイデア
topics:
  - "apple"
  - "ios"
  - "healthkit"
published: true
---
# HealthKit

[ヘルスケアとフィットネス - Apple Developer](https://developer.apple.com/jp/health-fitness/)

# [HealthKit フレームワークについて](https://developer.apple.com/documentation/healthkit/about_the_healthkit_framework)

- アプリ間で健康とフィットネスのデータを共有
- データ型と単位を事前定義されたリストに制限
- HealthKitデータ
  - 特性データ (**characteristic data)**
    - ユーザーの生年月日、血液型、生物学的性別、肌のタイプなど
    - アプリケーションは特性データを保存できない
  - サンプルデータ (sample)
  - トレーニングデータ (workout)
  - ソースデータ
  - 削除されたオブジェクト
  - **[HKObject](https://developer.apple.com/documentation/healthkit/hkobject)**
    - すべての HealthKit サンプル タイプのスーパークラス
- iPhone と Apple Watch にはそれぞれ独自の HealthKit ストアがある

# HealthKit のセットアップ

1. [アプリで HealthKit を有効](https://developer.apple.com/documentation/xcode/configuring-healthkit-access)にする
    - **HealthKit 機能をターゲットに追加する**
        ![image1.png](/images/ec1f8dd4bafeaf/image1.png)
    - 追加後の状態
        ![image2.png](/images/ec1f8dd4bafeaf/image2.png)
        - 「Clinical Health Records」とは?
            > 臨床記録（Clinical Health Records）とは、患者の健康状態や受けた治療に関する情報を含む記録のことを指します

2. `NSHealthUpdateUsageDescription` や `NSHealthShareUsageDescription` の設定
    - `Info.plist` に `NSHealthUpdateUsageDescription` ,  `NSHealthShareUsageDescription` を設定します
    - Xcode13以降でのInfo.plistの設定は以下を参照
        - [Xcode 13以上でInfo.plistを安全かつ簡単に作成する](https://zenn.dev/ruwatana/articles/2045140478b1de)
3. [HealthKit が現在のデバイスで利用できることを確認してください。](https://developer.apple.com/documentation/healthkit/hkhealthstore/1614180-ishealthdataavailable)
4. アプリの HealthKit ストアを作成します。
5. [データの読み取りと共有の許可をリクエストします。](https://developer.apple.com/documentation/healthkit/authorizing_access_to_health_data)

# テストデータ関連

- [https://github.com/ashtom/hkimport](https://github.com/ashtom/hkimport)
  - 実際のデバイスのデータをシュミレータに取り込むことができる

- [https://github.com/dogsheep/healthkit-to-sqlite/tree/main](https://github.com/dogsheep/healthkit-to-sqlite/tree/main)

  ↑こんなのもある
  - ExportしたデータをSQLiteのデータベースへ変換する事ができる

# 参考になりそうなリポジトリ

- [https://github.com/EvanCooper9/Friendly-Competitions](https://github.com/EvanCooper9/Friendly-Competitions)

- [https://github.com/ljaniszewski00/Fit-Vein](https://github.com/ljaniszewski00/Fit-Vein)

# 参考URL

- [初めてのHealthKit](https://zenn.dev/ueshun/articles/dd700cdbb61f8d)

- [（iOS）HealthKitを使って体重記録アプリを作る](https://zenn.dev/moutend/articles/fba6cfbf4027a2)

- [Swift: HealthKitに体温データを入力する。できるだけ公式ドキュメントだけを見て。 - Qiita](https://qiita.com/sYamaz/items/cedfd869f74f14b4b25b)

- [【Swift】HealthKitの歩数（StepCount）データを取得して表示する](https://kita-note.com/swift-healthkit-show-stepcount)