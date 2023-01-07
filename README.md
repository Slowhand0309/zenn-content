# Zenn CLI

* [📘 How to use](https://zenn.dev/zenn/articles/zenn-cli-guide)

## Preview

`docker compose up` で起動された状態で以下にアクセスするとPreviewが表示されます

```text
http://localhost:8000/
```

## 新しく記事を作成する場合

```sh
yarn article
```

## 記事を公開する場合

記事の `published` を `true` に設定して `main` ブランチにマージする
