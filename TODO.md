# GitHub PR通知アプリ - 実装TODO

## 概要

自分が関わるPRへのコメントをターミナルTUIで一覧管理し、デスクトップ通知する常駐アプリ。
GitHub APIへのアクセスは `gh` CLIを経由する。

### 通知対象

- 自分が作成したPRへのコメント
- 自分がレビュアーのPRへのコメント
- 自分がアサイニーのPRへのコメント

---

## アーキテクチャ

```
[常駐プロセス (MoonBit native)]
  |
  |-- ターミナルTUI (メインスレッド)
  |     |-- コメント一覧表示 (未読/既読)
  |     |-- PR別グルーピング
  |     |-- キーボード操作 (選択, 既読, ブラウザで開く)
  |     |
  |-- バックグラウンドポーリング (N秒間隔)
  |     |-- gh api: 対象PR一覧の取得
  |     |-- gh api: 各PRの新規コメント取得
  |     |
  |     v
  |-- 差分検出 → 新規コメントをリストに追加
  |     |
  |     v
  |-- デスクトップ通知 (osascript) + TUI更新
```

### TUI画面イメージ

```
GitHub PR Notifier                          [3 unread] polling: 60s
──────────────────────────────────────────────────────────────────
 repo/name #42: Fix login bug                        (author)
   * @alice  2m ago  「LGTMです、1点だけ修正お願いします」
     @bob   15m ago  「テスト追加しました」

 repo/name #38: Add dark mode                        (reviewer)
   * @carol  5m ago  「このアプローチで進めてよいですか？」

──────────────────────────────────────────────────────────────────
 j/k:move  Enter:detail  r:mark read  o:open in browser  q:quit
```

---

## TODO

### Phase 1: gh CLI連携の基盤

- [ ] **1-1. gh CLIの実行基盤**
  - `@process.collect_stdout` でghコマンドを実行し標準出力をキャプチャ
  - 終了コードによるエラーハンドリング
  - 利用パッケージ: `mizchi/x/process` (async関数)

- [ ] **1-2. gh API呼び出しのラッパー**
  - `gh api` コマンドを使ったGitHub REST API呼び出し
  - JSONレスポンスのパース (`gh api --jq` でフィルタ、またはMoonBit標準の `@json` でパース)

### Phase 2: データモデルとPR一覧の取得

- [ ] **2-1. データモデル定義**
  - `PullRequest`: number, title, url, repo, role(author/reviewer/assignee)
  - `Comment`: id, pr_number, author, body, created_at, read(既読フラグ)
  - `AppState`: コメントリスト, カーソル位置, フィルタ状態

- [ ] **2-2. 対象リポジトリの設定**
  - 監視対象のリポジトリ一覧を設定ファイル or コマンドライン引数で指定
  - 形式: `owner/repo`

- [ ] **2-3. 自分が関わるPRの取得**
  - `gh api /repos/{owner}/{repo}/pulls?state=open` で全openなPRを取得
  - 以下の条件でフィルタリング:
    - `user.login` が自分 (author)
    - `assignees[].login` に自分が含まれる (assignee)
    - `requested_reviewers[].login` に自分が含まれる (reviewer)
  - または個別に取得:
    - `gh pr list --repo {owner/repo} --author @me --json number,title,url`
    - `gh pr list --repo {owner/repo} --assignee @me --json number,title,url`
    - `gh pr list --repo {owner/repo} --search "review-requested:@me" --json number,title,url`

### Phase 3: コメントの取得と差分検出

- [ ] **3-1. PRコメントの取得**
  - `gh api /repos/{owner}/{repo}/pulls/{number}/comments` (レビューコメント)
  - `gh api /repos/{owner}/{repo}/issues/{number}/comments` (一般コメント)
  - レスポンスからコメントID, 作成日時, 作者, 本文を抽出

- [ ] **3-2. 既読管理**
  - コメントごとに未読/既読フラグを管理
  - 状態をローカルに永続化: `~/.config/github_noti/state.json`
  - `@fs.write_file` / `@fs.read_file` で読み書き

- [ ] **3-3. 自分のコメントを除外**
  - `comment.user.login` が自分の場合はリストに追加しない

### Phase 4: ターミナルTUI

- [ ] **4-1. ターミナル制御の基盤**
  - ANSIエスケープシーケンスによる画面制御
  - rawモード (カノニカルモード無効化) でキー入力を即時取得
  - 画面クリア・カーソル移動・色付き出力
  - native FFI: `tcgetattr` / `tcsetattr` でターミナル設定

- [ ] **4-2. コメント一覧画面**
  - PR別にグルーピングしてコメントを表示
  - 未読コメントをマーク (`*`) で視覚的に区別
  - 各コメントに: 作者, 経過時間, 本文プレビュー (先頭N文字)
  - ヘッダー: 未読数, ポーリング間隔

- [ ] **4-3. キーボード操作**
  - `j` / `k`: カーソル上下移動
  - `Enter`: コメント詳細表示 (本文全体)
  - `r`: 選択コメントを既読にする
  - `R`: 全コメントを既読にする
  - `o`: 選択コメントのPRをブラウザで開く (`gh pr view --web`)
  - `f`: フィルタ切替 (全て / 未読のみ)
  - `q`: 終了

- [ ] **4-4. コメント詳細画面**
  - コメント本文の全文表示
  - PR情報 (タイトル, URL)
  - `Esc` / `q` で一覧に戻る

### Phase 5: デスクトップ通知

- [ ] **5-1. macOS通知の送信**
  - `osascript -e 'display notification "body" with title "title"'` で通知
  - 新規コメント検出時にTUI更新と同時に発火
  - 通知内容: PR名, コメント者, コメント本文(先頭N文字)

### Phase 6: 常駐プロセス

- [ ] **6-1. ポーリングループ**
  - 設定可能なインターバル(デフォルト60秒)で定期実行
  - TUIのイベントループと並行して動作
  - 新規コメント取得時にTUIを再描画

- [ ] **6-2. 設定ファイル**
  - 監視対象リポジトリ一覧
  - ポーリング間隔(秒)
  - 設定ファイルパス: `~/.config/github_noti/config.json`

- [ ] **6-3. シグナルハンドリング**
  - Ctrl+C (SIGINT) での正常終了
  - ターミナルのrawモードを確実に復元

### Phase 7: 改善・拡張

- [ ] **7-1. GitHub Notifications APIの活用**
  - `gh api /notifications` を使えばポーリング効率を改善できる
  - `If-Modified-Since` ヘッダーでAPI呼び出し回数を削減
  - rate limit対策

- [ ] **7-2. ログ出力**
  - 動作確認用のログ（取得したPR数, 新規コメント数など）

- [ ] **7-3. launchd / システムサービス化**
  - macOS launchdへの登録でログイン時に自動起動

---

## 使用する主な gh コマンド

```bash
# 自分のユーザー名取得
gh api user --jq '.login'

# 自分が作成したPR一覧
gh pr list --repo owner/repo --author @me --state open --json number,title,url

# 自分がアサインされたPR一覧
gh pr list --repo owner/repo --assignee @me --state open --json number,title,url

# 自分がレビューリクエストされたPR一覧
gh pr list --repo owner/repo --search "review-requested:@me" --state open --json number,title,url

# PRのレビューコメント取得
gh api repos/owner/repo/pulls/123/comments --jq '.[].{id,user:.user.login,body,created_at}'

# PRの一般コメント取得
gh api repos/owner/repo/issues/123/comments --jq '.[].{id,user:.user.login,body,created_at}'

# PRをブラウザで開く
gh pr view --repo owner/repo 123 --web

# 通知API (効率的なポーリング)
gh api notifications --jq '.[] | select(.reason == "comment" or .reason == "review_requested")'
```

## 利用する mizchi/x パッケージ

`mizchi/x` (v0.1.5) が提供するクロスプラットフォームI/O抽象を活用する。
ビルドターゲットは **native** を想定。

| 用途 | パッケージ | 主なAPI |
|------|-----------|---------|
| コマンド実行 | `mizchi/x/process` | `collect_stdout(cmd, args)` → `(Int, &@io.Data)` |
| ファイルI/O | `mizchi/x/fs` | `read_file`, `write_file`, `exists`, `mkdir` |
| 環境変数・引数 | `mizchi/x/sys` | `get_env_var`, `get_cli_args`, `exit` |
| 標準入出力 | `mizchi/x/stdio` | `stdin`, `stdout`, `stderr` (TUIで利用) |

- 全てasync関数。MoonBitのasyncランタイム上で動作
- JSONパースはMoonBit標準ライブラリの `@json` を使用

## 技術的な検討事項

- **ターミナルrawモード**: キー入力即時取得のため `tcgetattr`/`tcsetattr` のFFIが必要。`mizchi/x/stdio` で対応できるか、自前FFIか要調査
- **スリープ / タイマー**: ポーリング間隔の待機方法。`moonbitlang/async` にsleep相当があるか要調査。なければnative FFIで `usleep` を呼ぶ
- **asyncエントリポイント**: `main` から async関数を呼ぶ方法の確認
- **TUIとポーリングの並行実行**: キー入力待ちとポーリングタイマーを同時に扱う非同期設計
