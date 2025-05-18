---
title: "Cloud Run × SQLite構成のクラウド運用 Litestream × Cloud Storageでレプリケーションを試す"
emoji: "☁️"
type: "tech" # tech: 技術記事 / idea: アイデア
topics:
  - "googlecloud"
  - "cloudrun"
  - "litestream"
  - "hono"
  - "kysely"
published: true
---
# 概要

**Cloud Run × Litestream** を組み合わせ、コンテナ内の SQLite ファイルを **Cloud Storage へリアルタイム複製**できるかを検証しました。ローカルでは **DevContainer** でサクッと **Hono + Kysely + SQLite** の開発環境を構築し、**MinIO** を立てて Litestream の挙動を試し、動作確認用に **ユーザー CRUD API** を実装し、更新内容がちゃんとレプリケートされるかをチェックしています。最終的に GCP へ載せるため、**Artifact Registry** や **Cloud Storage バケット**の準備・権限まわりもセットアップ。この記事では、そのやってみた過程とハマりどころをまとめました。

# 環境構築

## ローカルで動く環境構築

以下の記事をベースに環境を構築していきたいと思います。

https://zenn.dev/slowhand/articles/a9e6a31b6215d2

Devcontainerを使用する構成に変更して `.devcontainer` ディレクトリを作成し、以下ファイルを作成します。

- Dockerfile

```docker
FROM node:22.15.0-bullseye-slim

ARG username=vscode
ARG useruid=1000
ARG usergid=${useruid}

RUN set -ex \
    && apt-get update \
    && apt-get install -y \
        ca-certificates \
        sudo \
        sqlite3 \
        wget \
        --no-install-recommends \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    # Delete node user with uid=1000 and create vscode user with uid=1000
    && userdel -r node \
    && groupadd --gid ${usergid} ${username} \
    && useradd -s /bin/bash --uid ${useruid} --gid ${usergid} -m ${username} \
    && echo ${username} ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/${username} \
    && chmod 0440 /etc/sudoers.d/${username}

RUN wget https://github.com/benbjohnson/litestream/releases/download/v0.3.13/litestream-v0.3.13-linux-amd64.tar.gz \
    -O litestream.tar.gz \
    && tar -xzf litestream.tar.gz -C ./ \
    && mv litestream /usr/local/bin/ \
    && rm litestream.tar.gz \
    && chmod +x /usr/local/bin/litestream

USER ${username}
```

- compose.yml

```yaml
volumes:
  minio_data:
  modules_data:

name: cloudrun-litestream-example
services:
  app:
    build: .
    volumes:
      - ..:/usr/src
      - modules_data:/usr/src/node_modules
    command: tail -f /dev/null
    working_dir: /usr/src
  minio:
    image: minio/minio:RELEASE.2025-02-18T16-25-55Z
    volumes:
      - minio_data:/minio/data
    command: server --console-address ':9001' /minio/data
    ports:
      - 9000:9000
      - 9001:9001
```

- devcontainer.json (拡張機能などはお好みで)

```json
{
  "name": "CloudRun Litestream Example Remote Container Dev",
  "dockerComposeFile": ["compose.yaml"],
  "service": "app",
  "workspaceFolder": "/usr/src",
  "customizations": {
    "vscode": {
      "extensions": ["dbaeumer.vscode-eslint", "esbenp.prettier-vscode"],
      "settings": {
        "editor.tabSize": 2,
        "editor.formatOnSave": true,
        "editor.codeActionsOnSave": {
          "source.fixAll.eslint": "always"
        },
        "files.insertFinalNewline": true,
        "files.trimFinalNewlines": true
      }
    }
  },
  "features": {
    "ghcr.io/devcontainers/features/git:1": {}
  },
  "postAttachCommand": ".devcontainer/postAttach.sh",
  "remoteUser": "vscode"
}
```

- postAttach.sh

```bash
#!/bin/sh

cd `dirname $0`
cd ..
sudo chown -R vscode node_modules
```

# ローカルで簡単なAPI実装

👇こちらをベースに **Kysely×Hono×SQLite** 構成で簡単なCRUD APIを実装してみます。

https://zenn.dev/slowhand/articles/6598214b1a738a

## プロジェクト作成

まずは Hono で Nodejs用のプロジェクトを作成します。

```bash
$ yarn create hono .
yarn create v1.22.22
[1/4] Resolving packages...
[2/4] Fetching packages...
[3/4] Linking dependencies...
[4/4] Building fresh packages...

success Installed "create-hono@0.18.0" with binaries:
      - create-hono
create-hono version 0.18.0
✔ Using target directory … .
✔ Which template do you want to use? nodejs
✔ Directory not empty. Continue? Yes
✔ Do you want to install project dependencies? Yes
✔ Which package manager do you want to use? yarn
✔ Cloning the template
✔ Installing project dependencies
🎉 Copied project files
```

上記の記事と同様に `.devcontainer/postAttach.sh` の設定と `.devcontainer/compose.yaml` にportの設定を追加し [http://localhost:3000](http://localhost:3000/) にアクセスして `Hello Hono!` が表示されていればOKです。

次に [kysely-ctl](https://github.com/kysely-org/kysely-ctl) を使ってテストテーブルを作成していきたいと思います。SQLiteのdialectとしてKyselyの[ドキュメント](https://kysely-org.github.io/kysely-apidoc/classes/SqliteDialect.html)にある **[better-sqlite3](https://github.com/WiseLibs/better-sqlite3)** を同じように使って進めていきたいと思います。

早速必要なパッケージをインストールしていきます。

```bash
$ yarn add kysely better-sqlite3
$ yarn add -D kysely-ctl @types/better-sqlite3
```

次に Kysely の config ファイルを生成します。

```bash
yarn kysely init
```

最終的な `.config/kysely.config.ts` は以下の様に設定しました。

```tsx
import Database from 'better-sqlite3';
import { SqliteDialect } from 'kysely';
import { defineConfig } from 'kysely-ctl';

export default defineConfig({
  dialect: new SqliteDialect({
    database: new Database('db.sqlite'),
  }),
  migrations: {
    migrationFolder: 'migrations',
  },
  //   plugins: [],
  //   seeds: {
  //     seedFolder: "seeds",
  //   }
});
```

## Userテーブル作成

上記記事と同様に `User` テーブルを作成します。その際の `migration` ファイルはSQLite用に以下内容に修正し増田。

```tsx
import { sql, type Kysely } from 'kysely';

export async function up(db: Kysely<any>): Promise<void> {
  await db.schema
    .createTable('users')
    .addColumn('id', 'integer', (col) => col.primaryKey())
    .addColumn('first_name', 'text', (col) => col.notNull())
    .addColumn('last_name', 'text')
    .addColumn('created_at', 'text', (col) =>
      col.defaultTo(sql`CURRENT_TIMESTAMP`).notNull()
    )
    .addColumn('updated_at', 'text', (col) =>
      col.defaultTo(sql`CURRENT_TIMESTAMP`).notNull()
    )
    .execute();
}

export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.dropTable('users').execute();
}
```

これでmigration実施し、Userテーブルが作成されていればOKです。

![image1.png](/images/99f4ae40cbaaea/image1.png)

## **シードデータ登録 & API実装**

上記記事の「**シードデータ登録**」を参考にデータ登録を実施します。API実装も基本上記記事のままでSQLite用に少し修正が必要です。

`src/types.ts` の `User` モデルは `better-sqlite3` がDateオブジェクトをサポートしていない為、以下の様に変更します。

```tsx
export type User = {
  id?: number;
  first_name: string;
  last_name: string;
  created_at?: string; // Date -> string
  updated_at?: string; // Date -> string
};
```

以下SQLite用に修正した `src/index.ts` になります。

```tsx
import { serve } from '@hono/node-server';
import SQLiteDatabase from 'better-sqlite3';
import { Hono } from 'hono';
import { Kysely, SqliteDialect } from 'kysely';
import type { Database } from './types.js';

const dialect = new SqliteDialect({
  database: new SQLiteDatabase('db.sqlite'),
});

export const db = new Kysely<Database>({
  dialect,
});

const app = new Hono();

app.get('/users', async (c) => {
  const users = await db.selectFrom('users').selectAll().execute();
  return c.json(users);
});

app.get('/users/:id', async (c) => {
  const id = c.req.param('id');
  const user = await db
    .selectFrom('users')
    .selectAll()
    .where('id', '=', Number(id))
    .executeTakeFirst();
  if (!user) {
    return c.notFound();
  }
  return c.json(user);
});

app.post('/users', async (c) => {
  const { first_name, last_name } = await c.req.json();
  const user = await db
    .insertInto('users')
    .values({ first_name, last_name })
    .returningAll()
    .executeTakeFirst();
  return c.json(user, 201);
});

app.put('/users/:id', async (c) => {
  const id = c.req.param('id');
  const { first_name, last_name } = await c.req.json();
  const user = await db
    .updateTable('users')
    // better-sqlite3はDateオブジェクトを渡せないので toISOString を使用
    .set({ first_name, last_name, updated_at: new Date().toISOString() })
    .where('id', '=', Number(id))
    .returningAll()
    .executeTakeFirst();
  if (!user) {
    return c.notFound();
  }
  return c.json(user);
});

app.delete('/users/:id', async (c) => {
  const id = c.req.param('id');
  const user = await db
    .deleteFrom('users')
    .where('id', '=', Number(id))
    .returningAll()
    .executeTakeFirst();
  if (!user) {
    return c.notFound();
  }
  return c.json(user);
});

serve(
  {
    fetch: app.fetch,
    port: 3000,
  },
  (info) => {
    console.log(`Server is running on http://localhost:${info.port}`);
  }
);
```

API叩いてちゃんとCRUDが動作していたらOKです。

# ローカルでLitestream×**MinIO構成で動作させる**

次にローカル上でLitestreamを動作させ、MinIOへレプリケーションを実施する様にしてみたいと思います。

https://zenn.dev/slowhand/articles/a9e6a31b6215d2

基本上記の記事を元に進めて行き、`litestream.yml` はパスが異なる為以下の内容で作成しました。

```yaml
dbs:
  - path: /usr/src/db.sqlite
    replicas:
      - type: s3
        bucket: litestream-bucket
        path: db.sqlite
        endpoint: http://minio:9000
        region: us-east-1
        access-key-id: xxxxxxxx
        secret-access-key: xxxxxxx
        force-path-style: true
```

ここまでできたら早速Litestreamを動かして動作確認してみたいと思います。継続的にレプリケーションを実施し、ちゃんと同期できているか確認します。

```bash
litestream replicate -config ./litestream.yml
```

上記コマンドを実施し継続的にレプリケーションする様にしときます。ちなみに現在のDBの内容は以下の様になっています。

![image2.png](/images/99f4ae40cbaaea/image2.png)

ここでデータを1件登録してみます。

```bash
$ curl -H "Content-Type: application/json" \
-X POST \
-d "{\"first_name\": \"Ichiro\", \"last_name\": \"Tanaka\"}" \
http://localhost:3000/users
```

次に `litestream` を `Ctrl+C` で止めて別パスでdbをリストアし、中身を確認してみます。

```bash
$ litestream restore -o restore_db.sqlite -config ./litestream.yml /usr/src/db.sqlite
$ sqlite3 restore_db.sqlite
SQLite version 3.34.1 2021-01-20 14:10:07
Enter ".help" for usage hints.
sqlite> .table
_litestream_lock       kysely_migration       users
_litestream_seq        kysely_migration_lock
sqlite> SELECT * FROM users;
1|Taro|Yamada|2025-05-06 23:26:12|2025-05-06 23:26:12
2|Kenta|Fujimoto|2025-05-06 23:26:12|2025-05-06T23:38:30.072Z
3|Ichiro|Tanaka|2025-05-07 00:02:40|2025-05-07 00:02:40
```

ちゃんと同期できていそうです ✨ 

最後にコンテナ起動時にレプリケーションが走るように `.devcontainer/postAttach.sh` を以下に修正しときます。

```bash
yarn dev &

# start litestream
litestream replicate -config ./litestream.yml
```

# デプロイ用の構成を追加

まずはレプリケーション先のCloudStorage、Artifact Registryの作成までを実施して行きます。

[gcloud CLI](https://cloud.google.com/sdk/gcloud?hl=ja) を使って作業する為 `.devcontainer/compose.yaml` に以下serviceを追加しときます。

```yaml
volumes:
  # ...
  # ↓追加
  gcloud_config:
  docker_config:

name: cloudrun-litestream-example
services:
  # ...
  # ↓追加
  infra:
    image: google/cloud-sdk:516.0.0-slim
    volumes:
      - ..:/usr/src
      - gcloud_config:/root/.config/gcloud
      - docker_config:/root/.docker
    working_dir: /usr/src
    command: tail -f /dev/null
```

今回はArtifact RegistryでのDockerイメージ作成の為、Docker in Dokcer構成が必要な為 `.devcontainer/devcontainer.json` を上書きした `.devcontainer/devcontainer-infra.json` を以下内容で作成します。

```json
{
  "name": "CloudRun Litestream Infra Example Remote Container Dev",
  "dockerComposeFile": ["compose.yaml"],
  "service": "infra",
  "workspaceFolder": "/usr/src",
  "features": {
    "ghcr.io/devcontainers/features/git:1": {},
    "ghcr.io/devcontainers/features/docker-in-docker:2": {},
    "ghcr.io/devcontainers/features/node:1": {
      "version": "22.15.0"
    }
  }
}
```

👆 `features/ghcr.io/devcontainers/features/docker-in-docker:2` で Docker in Dockerが使えるようにしています。

GUIからは `devcontainer.json` を上書きして起動はできなさそうな為、[CLI](https://github.com/devcontainers/cli)を使って起動します。

```bash
# devcontainer cli をインストール
$ npm install -g @devcontainers/cli
# devcontainer-infra.json で上書きする形で起動
$ devcontainer up --workspace-folder . \
    --config .devcontainer/devcontainer.json \
    --override-config .devcontainer/devcontainer-infra.json
```

## デプロイ用のDockerfileの作成

今回お試しなので手元で `users` テーブルやseedデータを登録済みの db.sqliteを用意しときます。

```bash
$ yarn kysely migrate latest
$ yarn kysely seed:run
$ db.sqlite
SQLite version 3.34.1 2021-01-20 14:10:07
Enter ".help" for usage hints.
sqlite> .tables
kysely_migration       kysely_migration_lock  users
sqlite> select * from users;
1|Taro|Yamada|2025-05-13 00:47:34|2025-05-13 00:47:34
2|Hanako|Suzuki|2025-05-13 00:47:34|2025-05-13 00:47:34
# パーミッションを変更しておく
$ chmod 777 db.sqlite
```

準備ができたので、以下内容の `Dockerfile` を作成しときます。

```docker
# ---------- 1) ビルドステージ ----------
FROM node:22.15.0-bullseye-slim AS build
WORKDIR /usr/src/app

RUN set -ex \
    && apt-get update \
    && apt-get install -y \
        ca-certificates \
        wget \
        --no-install-recommends \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 依存関係をインストール（開発依存は除外）
COPY package.json yarn.lock* ./
RUN --mount=type=cache,target=/usr/local/share/.cache/yarn \
    yarn install --frozen-lockfile

COPY tsconfig.json .
COPY src ./src
RUN yarn build

ARG LITESTREAM_VER=v0.3.13
RUN wget https://github.com/benbjohnson/litestream/releases/download/${LITESTREAM_VER}/litestream-${LITESTREAM_VER}-linux-amd64.tar.gz \
    -O litestream.tar.gz \
    && tar -xzf litestream.tar.gz -C ./ \
    && mv litestream /usr/local/bin/ \
    && rm litestream.tar.gz \
    && chmod +x /usr/local/bin/litestream

# ---------- 2) ランタイムステージ ----------
FROM node:22.15.0-bullseye-slim

ENV PORT=8080
EXPOSE 8080

WORKDIR /usr/src/app

COPY --from=build /usr/src/app/node_modules ./node_modules
COPY --from=build /usr/src/app/dist ./dist
COPY --from=build /usr/local/bin/litestream /usr/local/bin/litestream
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY litestream.yml .
COPY db.sqlite .

# ---------- エントリポイント ----------
# ・DB が無ければレプリカから restore
# ・その後 replicate -exec でアプリを子プロセスとして起動
ENTRYPOINT ["/bin/sh","-c", "\
  litestream replicate -config ./litestream.yml -exec 'node dist/index.js' \
"]

```

## CloudStorageのバケット作成

上記の `devcontainer up` で立ち上げたコンテナ内に入り、まずは認証作業を実施して行きます。

```bash
gcloud auth login --no-launch-browser
```

👆のコマンドを実施し、表示されたURLにアクセスし許可すると verification code が取得できるのでコピペして認証を完了しときます。

```bash
# ちゃんと認証できているか↓のコマンドを実施して確認
$ gcloud projects list
# デフォルトの作業プロジェクトを設定しておくと便利
$ gcloud config set project <PROJECT_ID>
$ gcloud config list #=> プロジェクト設定確認
```

これで準備ができたので、早速レプリケーション先のバケットを作成しときます。

```bash
gcloud storage buckets create gs://litestream-example-bucket \
  --uniform-bucket-level-access \
  --location=asia-northeast1
```

## Artifact Registryのリポジトリ作成

まずは `Artifact Registry API` が有効になっているか確認し、必要あれば有効にしときます。

```bash
$ gcloud services list --enabled | grep artifactregistry #=> 有効になっていれば表示される
$ gcloud services enable artifactregistry.googleapis.com # 必要あれば有効化
```

準備ができたのでリポジトリを作成しときます。

```bash
gcloud artifacts repositories create litestream-example-repository \
    --repository-format=docker \
    --location=asia-northeast1
```

最後に `asia‑northeast1-docker.pkg.dev` への `docker push` できる様に認証しときます。

```bash
gcloud auth configure-docker asia-northeast1-docker.pkg.dev
```

## CloudRun用にPort指定と `litestream.yml` の修正

デプロイ環境で実行させる為に、以下を少し修正します。

- `src/index.ts`
  - 環境変数のPORTで値を渡せるようにしておく

```tsx
serve(
  {
    fetch: app.fetch,
    port: Number(process.env.PORT) || 3000, // ←修正
  },
  // ....
```

- `litestream.yml`
  - 👇を参考にCloud Storageに向けた設定にしてきます

https://litestream.io/guides/gcs/

```yaml
dbs:
  - path: /usr/src/app/db.sqlite
    replicas:
      - type: gcs
        bucket: litestream-example-bucket
        path: db.sqlite

```

# デプロイ作業

## Artifact RegistryのリポジトリへPush

Docker in Docker 環境で以下を実施し、作成したArtifact RegistryのリポジトリへPushします。

```bash
$ docker build --tag asia-northeast1-docker.pkg.dev/<PROJECT_ID>/litestream-example-repository/app:latest .
$ docker push asia-northeast1-docker.pkg.dev/<PROJECT_ID>/litestream-example-repository/app:latest
```

次にCloudRunからCloudStorageへアクセスできるサービスアカウントを作成しときます。

```bash
$ gcloud iam service-accounts create "litestream-example"
$ gcloud projects add-iam-policy-binding "<PROJECT_ID>" --member="serviceAccount:litestream-example@<PROJECT_ID>.iam.gserviceaccount.com" --role="roles/storage.admin"
```

## CloudRunへデプロイ

最後にCloudRunへデプロイします。

```bash
$ gcloud run deploy "litestream-example" \
    --region="asia-northeast1" \
    --image="asia-northeast1-docker.pkg.dev/<PROJECT_ID>/litestream-example-repository/app:latest" \
    --port="8080" \
    --service-account="litestream-example@<PROJECT_ID>.iam.gserviceaccount.com" \
    --max-instances=1 \
    --allow-unauthenticated
```

# 動作確認

デプロイ後実際にアクセスしてみて `users` 一覧が取得できていたらOKです。

```bash
$ curl https://xxxxxxxxxxxxxx.run.app/users
[
  {
    "id": 1,
    "first_name": "Taro",
    "last_name": "Yamada",
    "created_at": "2025-05-13 00:47:34",
    "updated_at": "2025-05-13 00:47:34"
  },
  {
    "id": 2,
    "first_name": "Hanako",
    "last_name": "Suzuki",
    "created_at": "2025-05-13 00:47:34",
    "updated_at": "2025-05-13 00:47:34"
  }
]
```

CloudStorageのバケット内にも `db.sqlite` が作成されています。

![image3.png](/images/99f4ae40cbaaea/image3.png)

次にユーザーを追加してみます。

```bash
$ curl -H "Content-Type: application/json" -X POST -d \
  "{\"first_name\": \"Ichiro\", \"last_name\": \"Tanaka\"}" \
  https://xxxxxxxxxxxxxxxxxxxxx.run.app/users
# => {"id":3,"first_name":"Ichiro","last_name":"Tanaka","created_at":"2025-05-13 20:07:06","updated_at":"2025-05-13 20:07:06"}
```

再度ユーザー一覧を取得すると、

```bash
$ curl https://xxxxxxxxxxxxxx.run.app/users
[
  {
    "id": 1,
    "first_name": "Taro",
    "last_name": "Yamada",
    "created_at": "2025-05-13 00:47:34",
    "updated_at": "2025-05-13 00:47:34"
  },
  {
    "id": 2,
    "first_name": "Hanako",
    "last_name": "Suzuki",
    "created_at": "2025-05-13 00:47:34",
    "updated_at": "2025-05-13 00:47:34"
  },
  {
    "id": 3,
    "first_name": "Ichiro",
    "last_name": "Tanaka",
    "created_at": "2025-05-13 20:07:06",
    "updated_at": "2025-05-13 20:07:06"
  }
]
```

ちゃんと反映されています！

次はちゃんとレプリケーションされているかの確認の為、Dockerイメージを少し修正して再度CloudRunをデプロイしてみます。

👇 デプロイ時にローカルの `db.sqlite` ファイルを削除しCloudStorageからrestoreする様にしています。

```docker
ENTRYPOINT ["/bin/sh","-c", "\
  rm -f ./db.sqlite;\
  litestream restore -if-replica-exists -config ./litestream.yml ./db.sqlite;\
  litestream replicate -config ./litestream.yml -exec 'node dist/index.js' \
"]
```

再度デプロイして、「リビジョン」タブから👇の様に再デプロイできていればOKです

![image4.png](/images/99f4ae40cbaaea/image4.png)

再度 `curl https://xxxxxxxxxxxxxx.run.app/users` を実施し登録したデータが取得できていればOKです!

# バッドノウハウ

### CloudRun実行時に `litestream shut down` のログが出てCloudStorageに何も表示されない

自分の場合はシンプルに `litestream.yml` の `path` が間違っていました…

### CloudRun実行時に以下エラーが発生する 1

```bash
SqliteError: attempt to write a readonly database
```

自分の場合は非ルートユーザーで試した時や `exec` コマンドを使用して `litestream replicate` を実行していた時に `db.sqlite` ファイルへ書き込み権限がなく上記のエラーが出ていました。

※ 本当は非ルートユーザーで実施するのが良いのかと思うのですが、今回はお試しという事でルートユーザーで実行しています。

### CloudRun実行時に以下エラーが発生する 2

```bash
tls: failed to verify certificate: x509: certificate signed by unknown authority
```

Dockerイメージ内に `ca-certificates` が存在していない為、 Litestream が GCS 証明書を検証できず発生している様です。修正方法としては `ca-certificates` をインストールするか上記のDockerfileの様にマルチステージングビルドの場合、ビルドステージから以下の様にCOPYしてやる方法があります。

```docker
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
```

# 参考URL

https://qiita.com/faable01/items/ac7418d671c6db5b966f

https://ushumpei.hatenablog.com/entry/2023/03/16/172353