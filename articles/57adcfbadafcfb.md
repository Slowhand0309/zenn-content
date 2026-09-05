---
title: "macOS→UbuntuでNo route to hostになった原因"
emoji: "🌐"
type: "tech"
topics:
  - "macos"
  - "ubuntu"
  - "ping"
  - "networking"
  - "troubleshooting"
published: false
---

# 概要

Ubuntuをインストールした小型PCへ、同じLAN内のmacOS端末から`ping`を実行したところ、次のようなエラーになりました。

```plain text
ping: sendto: No route to host
Request timeout for icmp_seq 0
```

Ubuntu側からmacOS端末やルーターへの`ping`は通るため、最初はUbuntuの固定IP設定、ファイアウォール、Wi-Fiと有線LANの競合などを疑いましが、しかし、最終的な原因は **macOS側で、****`ping`****を実行していたターミナルアプリに「ローカルネットワーク」へのアクセス権限が与えられていなかったこと** でした。。このせいで半日ハマってしまいました。。

原因が分かる「そんなこと〜」と思いますが、やっている時は考えもしない事なので同じような境遇で何かこの記事が役に立てば幸いです。

> 💡 **今回の教訓**

# 動作環境

端末を特定できるホスト名やIPアドレスは伏せています。

- macOS側：MacBook Air（M3）／macOS Tahoe 26.5.2

- Ubuntu側：Ubuntu 26.04 LTS（GNU/Linux 7.0.0-28-generic x86_64）をインストールした小型PC

- 同一ルーター配下のLAN

- Ubuntu側は固定IP

- macOS側からUbuntu側へ`ping`を実行

ネットワーク構成のイメージは次の通りです。

```plain text
macOS端末
  192.168.x.x
       |
       | Wi-Fiまたは有線LAN
       |
ルーター
       |
       | 有線LANまたはWi-Fi
       |
Ubuntu端末
  192.168.x.x
```

# 発生した症状

macOS側からUbuntu側へ`ping`すると、応答がありませんでした。

```bash
ping -c 3 192.168.x.x
```

```plain text
PING 192.168.x.x: 56 data bytes
ping: sendto: No route to host
Request timeout for icmp_seq 0
```

一方、Ubuntu側からは次の通信が成功しました。

```bash
ping -c 3 192.168.x.1
ping -c 3 192.168.x.x
```

- Ubuntuからルーターへの`ping`：成功

- UbuntuからmacOSへの`ping`：成功

- macOSからUbuntuへの`ping`：失敗

この時点で、Ubuntu側のNICやデフォルトルートはおおむね正常と判断できます。

# 最初に疑った原因

当初は、Ubuntu側を中心に確認しました。

- 固定IPのサブネットマスクが誤っている

- デフォルトゲートウェイがない

- 有線LANとWi-Fiが同時に有効になっている

- UFWやnftablesがICMPを拒否している

- ルーターのAP isolationや端末間通信禁止

- VPNや仮想ネットワークが経路を奪っている

これらは片方向通信でよくある原因なので、確認自体は無駄ではありません。

ただし、今回の決め手になったのは`tcpdump`でした。

# `tcpdump`でUbuntuまで届いているか確認する

Ubuntu側で、ARPとICMPを監視します。

```bash
sudo tcpdump -ni any 'arp or icmp'
```

その状態で、macOS側からUbuntuへ`ping`します。

```bash
ping -c 3 192.168.x.x
```

今回、Ubuntu側の`tcpdump`には **何も表示されませんでした**。

通常、同一LAN内の端末へ通信する場合、macOSは最初にARPを使って対象IPのMACアドレスを確認します。

少なくとも次のようなARPパケットがUbuntuへ届くはずです。

```plain text
Who has 192.168.x.x? Tell 192.168.x.x
```

しかしARPすら観測できない場合、Ubuntu側のUFWやICMP応答設定よりも前の段階で通信が止まっています。

> 🔍 **`tcpdump`****に何も出ない場合に疑う場所**

# 原因：macOSのローカルネットワーク権限

macOSでは、アプリがローカルネットワーク上の機器を検出・通信する際、アプリごとにアクセス許可が管理されます。

今回 [Ghostty](https://ghostty.org/) を使用していたのですが、この権限が無効になっていました。。。

設定は次の場所から確認できます。

1. **システム設定**を開く

1. **プライバシーとセキュリティ**を開く

1. **ローカルネットワーク**を開く

1. `ping`や`ssh`を実行しているターミナルアプリを有効にする

![](/images/57adcfbadafcfb/3aea252da4fa807e8531e1fb2e4404d1.png)

対象になり得るアプリは次のようなものです。

- ターミナル

- iTerm2

- Warp

- VS CodeやCursorなどの統合ターミナル

- IDE内のターミナル

権限を変更した後は、対象アプリを再起動し、再度`ping`を実行すると通信できるようになりました ✨

```bash
ping -c 3 192.168.x.x
```

```plain text
64 bytes from 192.168.x.x: icmp_seq=0 ttl=64 time=...
```

# なぜ「No route to host」になったのか

表示だけを見ると、ルーティングテーブルに問題があるように見えます。

しかし、`No route to host`は必ずしもLinuxの`ip route`に相当する経路設定ミスだけを意味しません。

OSやアプリのセキュリティ制御によってローカルネットワークへの送信が拒否された場合にも、呼び出し元には到達不能として返ることがあります。

そのため、次の2つは分けて考える必要があります。

- OSのルーティングテーブル上に経路があるか

- そのアプリが実際にLANへパケットを送信できるか

今回、前者は正常でしたが、後者がmacOSのプライバシー設定で止められていました。

# 効率的な切り分け手順

同じ症状が出た場合は、次の順番で確認すると早く特定できます。

## 1. 双方向の`ping`を試す

```bash
# macOSからUbuntu
ping -c 3 192.168.x.x

# UbuntuからmacOS
ping -c 3 192.168.x.x
```

片方向だけ成功する場合は、失敗方向の送信元と成功方向の受信元を重点的に確認します。

## 2. Ubuntu側のアドレスと経路を確認する

```bash
ip -br addr
ip route
ip route get 192.168.x.x
```

確認ポイントは次の通りです。

- 対象NICが`UP`になっている

- 固定IPが`192.168.x.x/24`のように設定されている

- 同一サブネットへのルートがある

- デフォルトルートがルーターを向いている

## 3. Ubuntu側で`tcpdump`を実行する

```bash
sudo tcpdump -ni any 'arp or icmp'
```

結果の見方は次の通りです。

| 観測結果 | 疑う場所 |
| --- | --- |
| 何も表示されない | 送信元の権限、VPN、ルーターの分離設定 |
| ARPだけ届く | UbuntuのIP設定、ARP応答、複数NIC |
| ICMP Requestは届くがReplyしない | UFW、nftables、ICMP設定 |
| RequestとReplyの両方が見える | 送信元や途中経路でReplyが破棄されている |

## 4. macOS側のローカルネットワーク権限を確認する

特に、標準ターミナル以外のターミナルアプリを利用している場合は最優先で確認します。

標準のターミナルアプリと別のターミナルアプリで結果が異なる場合、アプリ単位の権限差である可能性が高いです。

## 5. VPNやセキュリティソフトを確認する

次のようなソフトウェアを一時停止して確認します。

- VPNクライアント

- Cloudflare WARP

- Tailscale

- WireGuard

- 企業向けエンドポイントセキュリティ

macOS側の経路も確認できます。

```bash
route -n get 192.168.x.x
```

通常はWi-Fiまたは有線LANのインターフェースが表示されます。

`utun`系インターフェースが表示される場合、VPN経由になっている可能性があります。

## 6. ルーターの端末分離設定を確認する

- ゲストWi-Fiではないか

- AP isolationが有効ではないか

- プライバシーセパレーターが有効ではないか

- Wi-Fiと有線LANが別VLANになっていないか

ただし、今回のようにターミナルアプリの権限変更だけで解決する場合、ルーター設定の変更は不要です。

# `ssh`でも同様の問題になる

この問題は`ping`に限りません。

ローカルネットワーク権限がないターミナルアプリからは、次のようなLAN内通信も失敗する可能性があります。

```bash
ssh user@192.168.x.x
curl http://192.168.x.x:8080
nc -vz 192.168.x.x 22
```

そのため、新しいmacOS端末や新しいターミナルアプリを使い始めた直後にLAN内の開発機へ接続できない場合、まずローカルネットワーク権限を確認するとよさそうです。

# まとめ

今回の原因はUbuntuのネットワーク設定ではなく、macOS側のアプリ権限でした。

- Ubuntuから外向きの通信は成功していた

- macOSからUbuntuへの通信だけ失敗した

- Ubuntu側の`tcpdump`にはARPもICMPも届かなかった

- macOSのターミナルアプリへローカルネットワーク権限を付与すると解決した

ネットワーク障害では、エラーメッセージだけから原因箇所を決めつけず、**パケットがどこまで届いているか**を見ることが重要です。

`tcpdump`で受信がゼロなら、受信側のファイアウォールを掘り続けるより、送信元の権限や経路へ視点を移すと、切り分けがかなり早くなります。

# 参考

[https://support.apple.com/ja-jp/guide/mac-help/mchla4f49138/mac](https://support.apple.com/ja-jp/guide/mac-help/mchla4f49138/mac)

[https://support.apple.com/ja-jp/102281](https://support.apple.com/ja-jp/102281)

[https://ubuntu.com/server/docs/how-to/security/firewalls/](https://ubuntu.com/server/docs/how-to/security/firewalls/)
