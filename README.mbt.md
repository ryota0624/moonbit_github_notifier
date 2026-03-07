# github_noti

自分が関わるGitHub PRへのコメントを監視し、デスクトップ通知する常駐アプリ。

## 前提条件

- [MoonBit](https://www.moonbitlang.com/) がインストール済み
- [gh CLI](https://cli.github.com/) がインストール済みで認証済み (`gh auth login`)
- macOS (デスクトップ通知に `osascript` を使用)

## ビルド

```bash
moon build
```

## 実行

```bash
# 基本的な使い方
moon run cmd/main -- owner/repo

# 複数リポジトリを監視
moon run cmd/main -- owner/repo1 owner/repo2

# cmux notify で通知（osascript の代わり）
moon run cmd/main -- --cmux owner/repo

# 30秒間隔で監視
moon run cmd/main -- --interval 30 owner/repo
```

引数に監視したいリポジトリを `owner/repo` 形式で指定します。

## オプション

| フラグ | 説明 |
|--------|------|
| `--cmux` | 通知に `cmux notify` コマンドを使用（デフォルトは osascript） |
| `--dump <file>` | GitHub APIから取得したデータをJSONファイルに保存 |
| `--load <file>` | JSONファイルからデータを読み込んで表示（GitHub API不要） |
| `--exclude <file>` | 除外パターンファイルを指定（通知から除外） |
| `--interval <sec>` | ポーリング間隔を秒で指定（デフォルト: 60） |

### データのダンプとロード

動作検証やオフラインでの確認に便利です。

```bash
# GitHub APIからデータを取得しつつファイルに保存
moon run cmd/main -- --dump data.json owner/repo

# 保存したファイルから起動（GitHub API不要、リポジトリ引数も不要）
moon run cmd/main -- --load data.json
```

### 除外パターン

テキストファイルに1行ずつ除外パターンを記述します。コメントの `author` または `body` にパターンが含まれていれば通知から除外されます。`#` で始まる行はコメントとして無視されます。

```
# exclude.txt の例
dependabot
[bot]
codecov
```

```bash
moon run cmd/main -- --exclude exclude.txt owner/repo
```

## 通知対象

以下の条件に該当するopen状態のPRのコメントを取得します（自分のコメントは除外）:

- 自分が作成したPR
- 自分がレビュアーのPR
- 自分がアサイニーのPR

## 返信漏れ通知

ポーリング時に返信漏れ（自分が返信すべきコメント）を検知し、デスクトップ通知を送ります。

### 検知ルール

| 条件 | 返信漏れと判定 |
|------|--------------|
| 自分がAuthorのPR | 最後のコメントが他人 |
| 自分がAssigneeのPR | 最後のコメントが他人 |
| 自分がReviewerのPR | 自分がコメント済み かつ 最後のコメントが他人 |
| その他（roleなし） | 自分がコメント済み かつ 最後のコメントが他人 |

同じコメントに対する返信漏れ通知は、一度通知されると再通知されません（プロセス起動中）。

### テスト用トリガー

自分自身が PR に `missing` を含むコメントを投稿すると、返信漏れ通知がトリガーされます。通知パイプラインの動作確認に利用できます。

## デバッグ

環境変数 `DEBUG=true` で詳細ログを出力します。

```bash
DEBUG=true moon run cmd/main -- owner/repo
```

## データ保存

既読状態は `~/.config/github_noti/read_ids.json` に保存されます。

## ポーリング

起動後、指定間隔（デフォルト60秒）でGitHub APIをポーリングし、新規コメントや返信漏れがあればデスクトップ通知を表示します。
