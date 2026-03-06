# github_noti

自分が関わるGitHub PRへのコメントをターミナルで一覧管理し、デスクトップ通知する常駐アプリ。

## 前提条件

- [MoonBit](https://www.moonbitlang.com/) がインストール済み
- [gh CLI](https://cli.github.com/) がインストール済みで認証済み (`gh auth login`)
- macOS (デスクトップ通知に `osascript` を使用)

## ビルド

```bash
moon build --target native
```

バイナリは `_build/native/debug/build/cmd/main/main.exe` に生成されます。

## 実行

```bash
# moon run 経由
moon run cmd/main --target native -- owner/repo

# 複数リポジトリを監視
moon run cmd/main --target native -- owner/repo1 owner/repo2

# ビルド済みバイナリを直接実行
./_build/native/debug/build/cmd/main/main.exe owner/repo
```

引数に監視したいリポジトリを `owner/repo` 形式で指定します。

## 通知対象

以下の条件に該当するopen状態のPRのコメントを取得します（自分のコメントは除外）:

- 自分が作成したPR
- 自分がレビュアーのPR
- 自分がアサイニーのPR

## キー操作

| キー | 操作 |
|------|------|
| `j` | カーソルを下に移動 |
| `k` | カーソルを上に移動 |
| `r` | 選択中のコメントを既読にする |
| `R` | 全コメントを既読にする |
| `o` | 選択中のコメントのPRをブラウザで開く |
| `f` | 表示切替（全て / 未読のみ） |
| `q` | 終了 |

## 画面イメージ

```
GitHub PR Notifier                    [3 unread] [all]
──────────────────────────────────────────────────────────────────
 owner/repo #42: Fix login bug
> * @alice  2025-01-01T12:00:00Z  "LGTMです、1点だけ修正お願いします"
    @bob   2025-01-01T11:00:00Z  "テスト追加しました"

 owner/repo #38: Add dark mode
  * @carol  2025-01-01T10:00:00Z  "このアプローチで進めてよいですか？"

──────────────────────────────────────────────────────────────────
 j/k:move  r:read  R:read all  o:open  f:filter  q:quit
```

- `*` は未読コメント
- `>` はカーソル位置（反転表示）

## データ保存

既読状態は `~/.config/github_noti/read_ids.json` に保存されます。

## ポーリング

起動後、60秒間隔でGitHub APIをポーリングし、新規コメントがあればmacOSのデスクトップ通知を表示します。

## 既知の制限

- ターミナルのrawモードが未実装のため、キー入力後にEnterキーを押す必要があります
- ポーリング間隔は現在固定（60秒）です
