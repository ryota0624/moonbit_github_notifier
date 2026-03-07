# github_noti

自分が関わるGitHub PRへのコメントをターミナルで一覧管理し、デスクトップ通知する常駐アプリ。

## 前提条件

- [MoonBit](https://www.moonbitlang.com/) がインストール済み
- [gh CLI](https://cli.github.com/) がインストール済みで認証済み (`gh auth login`)
- macOS (デスクトップ通知に `osascript` を使用)

## ビルド

```bash
moon build --target js
```

## 実行

```bash
# 基本的な使い方
moon run cmd/main --target js -- owner/repo

# 複数リポジトリを監視
moon run cmd/main --target js -- owner/repo1 owner/repo2

# cmux notify で通知（osascript の代わり）
moon run cmd/main --target js -- --cmux owner/repo
```

引数に監視したいリポジトリを `owner/repo` 形式で指定します。

## オプション

| フラグ | 説明 |
|--------|------|
| `--cmux` | 通知に `cmux notify` コマンドを使用（デフォルトは osascript） |
| `--dump <file>` | GitHub APIから取得したデータをJSONファイルに保存 |
| `--load <file>` | JSONファイルからデータを読み込んで表示（GitHub API不要） |
| `--exclude <file>` | 除外パターンファイルを指定（表示・通知の両方に適用） |
| `--interval <sec>` | ポーリング間隔を秒で指定（デフォルト: 60） |

### データのダンプとロード

動作検証やオフラインでの確認に便利です。

```bash
# GitHub APIからデータを取得しつつファイルに保存
moon run cmd/main --target js -- --dump data.json owner/repo

# 保存したファイルからTUIを起動（GitHub API不要、リポジトリ引数も不要）
moon run cmd/main --target js -- --load data.json
```

### 除外パターン

テキストファイルに1行ずつ除外パターンを記述します。コメントの `author` または `body` にパターンが含まれていれば、表示と通知の両方から除外されます。`#` で始まる行はコメントとして無視されます。

```
# exclude.txt の例
dependabot
[bot]
codecov
```

```bash
moon run cmd/main --target js -- --exclude exclude.txt owner/repo
```

## 通知対象

以下の条件に該当するopen状態のPRのコメントを取得します（自分のコメントは除外）:

- 自分が作成したPR
- 自分がレビュアーのPR
- 自分がアサイニーのPR

## キー操作

| キー | 操作 |
|------|------|
| `j` / `↓` | カーソルを下に移動 |
| `k` / `↑` | カーソルを上に移動 |
| `r` | 選択中のコメントを既読にする |
| `R` | 全コメントを既読にする |
| `o` | 選択中のコメントのPRをブラウザで開く |
| `f` | 表示切替（全て / 未読のみ） |
| `q` / `Ctrl+C` | 終了 |

## データ保存

既読状態は `~/.config/github_noti/read_ids.json` に保存されます。

## ポーリング

起動後、60秒間隔でGitHub APIをポーリングし、新規コメントがあればデスクトップ通知を表示します。
