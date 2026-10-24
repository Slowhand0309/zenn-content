---
title: "Ubuntu上のGitをMacの1Passwordで認証する"
emoji: "🔑"
type: "tech"
topics:
  - "1password"
  - "ssh"
  - "git"
  - "ubuntu"
  - "github"
published: false
---

# 概要

MacからUbuntu端末へSSH接続し、そのUbuntu上で`git pull`や`git push`を行いたくなりました。

ただし、Gitホスティングサービス用の秘密鍵をUbuntuへコピーするのは避けたいところです。

そこで、Macで動いている**1Password SSH Agent**をUbuntuへ転送し、UbuntuからのGit認証をMac側で承認する構成にしました。

```plain text
Ubuntu上のGitコマンド
    ↓
SSH_AUTH_SOCK
    ↓ SSH Agent Forwarding
Macの1Password SSH Agent
    ↓ 生体認証で承認
Gitホスティングサービス
```

> 💡 **今回のポイント**

なお、今回利用するのは厳密には**1Password CLIの****`op`****コマンドではなく、1Password SSH Agent**です。Ubuntu側への1Password CLIのインストールは必要ありません。

# 前提

- MacからUbuntuへSSH接続できる

- Macの1PasswordにSSHキーを保存している

- 1Password SSH Agentを有効化している

- SSHキーの公開鍵をGitホスティングサービスへ登録している

- UbuntuにGitをインストールしている

この記事では、環境固有の情報を次のような一般的な値へ置き換えています。

```plain text
SSH接続名: dev-server
UbuntuのIPアドレス: 192.0.2.10
Ubuntuのユーザー名: developer
リポジトリ所有者: example-org
リポジトリ名: sample-repository
```

SSH接続自体の設定は、次の記事で行った構成を前提にしています。

[1Password SSH Agentで秘密鍵をMacに保存せずUbuntuへSSH接続する](https://app.notion.com/p/3aea252da4fa8082b07dedb6427de99b)

# Mac側でAgent Forwardingを有効にする

MacのSSH設定を開きます。

```bash
nano ~/.ssh/config
```

Ubuntuの接続設定へ`ForwardAgent yes`を追加します。

```javascript
Host dev-server
  HostName 192.0.2.10
  User developer
  IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
  ForwardAgent yes
```

`IdentityAgent`は、MacのSSHクライアントが1Password SSH Agentを利用するための設定です。

`ForwardAgent yes`を指定すると、Ubuntuへ接続した後のSSH認証要求もMac側のAgentへ転送されます。

> ⚠️ `ForwardAgent yes`を`Host *`へ設定するのは避けます。Agent Forwardingは、管理下にある信頼できる接続先だけに設定します。

一時的に試すだけなら、設定ファイルを変更せず`-A`オプションでも有効化できます。

```bash
ssh -A developer@192.0.2.10
```

今回は毎回利用するため、接続先を限定したうえで`~/.ssh/config`へ設定しました。

# Ubuntuへ接続し直す

設定を反映するため、すでにSSH接続中の場合はいったんログアウトします。

```bash
exit
```

Macから再接続します。

```bash
ssh dev-server
```

Agent ForwardingはSSHセッションの開始時に設定されるため、既存セッションのままでは反映されないことがあります。

# Ubuntu側でSSH_AUTH_SOCKを確認する

Ubuntuへ接続した状態で、次を実行します。

```bash
echo "$SSH_AUTH_SOCK"
```

正常に転送されていれば、次のような一時ソケットのパスが表示されます。

```plain text
/tmp/ssh-xxxxxxxx/agent.1234
```

何も表示されない場合は、Agent Forwardingが有効になっていません。

続いて、Ubuntuから利用できるSSHキーを確認します。

```bash
ssh-add -l
```

1Passwordに保存しているSSHキーのフィンガープリントが表示されれば、UbuntuからMacのSSH Agentを利用できています。

> 🔍 ここで表示されるのは秘密鍵そのものではありません。UbuntuからMacのAgentへ署名を依頼できる状態になっているだけで、秘密鍵がUbuntuへコピーされることはありません。

# UbuntuからGitHubへのSSH接続を確認する

GitHubを例に、SSH認証をテストします。

```bash
ssh -T git@github.com
```

Mac側に1Passwordの承認画面が表示されたら、生体認証などで許可します。

成功すると、次のようなメッセージが表示されます。

```plain text
Hi example-user! You've successfully authenticated, but GitHub does not provide shell access.
```

このメッセージにユーザー名が含まれていれば認証成功です。

なお、GitHubのSSHテストは認証に成功していても終了コード`1`を返します。メッセージが成功を示していれば問題ありません。

# SSH形式でリポジトリをcloneする

Ubuntu上で作業用ディレクトリを作成します。

```bash
mkdir -p ~/projects
cd ~/projects
```

SSH形式のURLでcloneします。

```bash
git clone git@github.com:example-org/sample-repository.git
```

clone後は、通常どおりGitを操作できます。

```bash
cd sample-repository
git pull
git switch -c feature/example
git push -u origin feature/example
```

SSH認証が必要になると、Mac側の1Passwordへ承認画面が表示されます。

# 既存リポジトリがHTTPS形式の場合

すでにclone済みの場合は、リモートURLを確認します。

```bash
git remote -v
```

次のようにHTTPS形式になっている場合、SSH Agentは利用されません。

```plain text
origin  https://github.com/example-org/sample-repository.git (fetch)
origin  https://github.com/example-org/sample-repository.git (push)
```

SSH形式へ変更します。

```bash
git remote set-url origin \
  git@github.com:example-org/sample-repository.git
```

変更後のURLを確認します。

```bash
git remote -v
```

次のようになれば変更完了です。

```plain text
origin  git@github.com:example-org/sample-repository.git (fetch)
origin  git@github.com:example-org/sample-repository.git (push)
```

# うまくいかなかった場合

## SSH_AUTH_SOCKが空になる

```bash
echo "$SSH_AUTH_SOCK"
```

何も表示されない場合は、次を確認します。

- Macの`~/.ssh/config`に`ForwardAgent yes`があるか

- 対象の`Host`設定が実際の接続名と一致しているか

- 設定変更後にSSH接続し直したか

- Mac側で1Password SSH Agentが有効になっているか

詳細を確認する場合は、Macからデバッグログ付きで接続します。

```bash
ssh -v dev-server
```

## The agent has no identitiesと表示される

```bash
ssh-add -l
```

次のメッセージが表示される場合があります。

```plain text
The agent has no identities.
```

この場合は、Mac側で次を確認します。

- 1PasswordにSSHキーアイテムが存在するか

- SSHキーがアーカイブされていないか

- SSH Agentが参照する保管庫にキーが保存されているか

- 1Passwordがロックされていないか

## Permission denied (publickey)になる

```plain text
Permission denied (publickey).
```

主な確認箇所は次の通りです。

- `ssh-add -l`で目的のキーが表示されるか

- SSHキーの公開鍵をGitホスティングサービスへ登録しているか

- リモートURLがHTTPSではなくSSH形式か

- 接続先が`git@github.com`になっているか

詳細ログはこちらで確認できます。

```bash
ssh -vT git@github.com
```

## Ubuntu側でAgent Forwardingが禁止されている

UbuntuのSSHサーバー設定を確認します。

```bash
sudo sshd -T | grep allowagentforwarding
```

次のように表示されれば許可されています。

```plain text
allowagentforwarding yes
```

無効になっている場合は、Ubuntuの`/etc/ssh/sshd_config`または`/etc/ssh/sshd_config.d/`配下の設定を確認します。

```javascript
AllowAgentForwarding yes
```

設定を変更した場合は、構文を確認してからSSHサービスを再読み込みします。

```bash
sudo sshd -t
sudo systemctl reload ssh
```

SSH設定を誤ると再接続できなくなる可能性があるため、現在のSSHセッションを残したまま別ターミナルから接続確認すると安全です。

## sudo gitを実行すると認証できない

次のような操作は基本的に避けます。

```bash
sudo git pull
sudo git push
```

`sudo`を使うと、SSH Agentの環境変数やGit設定が通常ユーザーと異なるため、転送したAgentを利用できない場合があります。

リポジトリの所有者や権限を修正し、通常ユーザーでGitを操作します。

```bash
sudo chown -R "$USER":"$USER" ~/projects/sample-repository
```

# セキュリティ上の注意

Agent Forwardingでは秘密鍵自体はUbuntuへ送られませんが、SSH接続中のUbuntuからMacのAgentへ署名を依頼できる状態になります。

そのため、次の点を意識します。

- 管理下にある信頼できるUbuntuだけで有効にする

- `Host *`へ`ForwardAgent yes`を設定しない

- 不要なSSHセッションは切断する

- Ubuntuの同一ユーザーで不審なプロセスを動かさない

- 重要な操作では1Passwordの承認内容を確認する

> 🔐 秘密鍵が転送されないことと、接続先を無条件に信頼してよいことは別です。Agent Forwardingは便利ですが、対象ホストを限定して使うのが前提です。

# まとめ

Macの1Password SSH AgentをUbuntuへ転送すると、秘密鍵をUbuntuへ保存せずに、Ubuntu上からGitのSSH認証を利用できます。

今回の流れは次の通りです。

```plain text
1. MacのSSH設定でForwardAgentを有効にする
2. Ubuntuへ接続し直す
3. SSH_AUTH_SOCKとssh-add -lを確認する
4. ssh -TでGitホスティングサービスへの認証を試す
5. SSH形式のURLでclone・pull・pushする
```

最初は「Ubuntuにも1Password CLIを入れる必要があるのでは」と考えましたが、対話的にMacからUbuntuへ接続して作業する用途では、SSH Agent Forwardingだけで十分でした。

秘密鍵を複数端末へ配布せずに済むため、個人用の開発サーバーやリモートワークステーションで使いやすい構成です。

# 参考

- [SSH agent forwarding with 1Password](https://www.1password.dev/ssh/agent/forwarding)

- [1Password SSH agent](https://www.1password.dev/ssh/agent)

- [SSH接続をテストする - GitHub Docs](https://docs.github.com/ja/authentication/connecting-to-github-with-ssh/testing-your-ssh-connection?platform=linux)

- [リモートリポジトリを管理する - GitHub Docs](https://docs.github.com/ja/get-started/git-basics/managing-remote-repositories)
