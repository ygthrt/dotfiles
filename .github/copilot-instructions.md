# Copilot Instructions for dotfiles リポジトリ

## リポジトリの目的と基本方針
macOS の設定ファイルを一元管理し、シンボリックリンクと Homebrew、mise を使用して環境セットアップを完全に自動化するリポジトリです。
このリポジトリにおける最も重要な開発方針は **「べき等性（何度実行しても安全）」** と **「副作用のない完全なドライラン環境の維持」** です。

## コーディング規約・絶対ルール (CRITICAL)
AI はコードを提案・生成する際、必ず以下のルールを厳守してください。

### 1. 破壊的変更には必ず `execute_cmd` ラッパーを使用する
`setup.sh` 内でシステムに状態変化をもたらすコマンド（`mkdir`, `ln`, `mv`, `curl`, ファイルへの `echo ... >>` など）を記述する場合は、直接実行せず、必ず `execute_cmd` 関数を経由させてください。
- **理由**: `./setup.sh --dry-run` 実行時にシステムを一切汚さず、変数が展開された正確な実行予定パスを出力させるため。
- **正しい文法**: `execute_cmd "ln -snf \"$DOTFILES_DIR/.config/app/config\" ~/.config/app/config"`
- **注意**: 変数が実行前に展開されるようダブルクォーテーション `" "` で囲み、内部のクォーテーションやスペースを含むパスは適切にエスケープ（`\"` など）してください。過剰なシングルクォーテーションによる変数の無効化は避けてください。

### 2. Brewfile の更新は専用エイリアス `brew-dump` を使う
Homebrew に新しいパッケージを追加した際、絶対に標準の `brew bundle dump` コマンドを使用（または提案）しないでください。
- **理由**: `mise` や `npm` 等でインストールされた言語系のツールまで Homebrew 管理物として混入し、次回セットアップ時にエラーとなるのを防ぐため。
- **正しい手順**: 隔離された PATH を用いる `.zshrc` 内のカスタムエイリアス `brew-dump` を実行するようユーザーに案内してください。

### 3. 機密情報（Secrets）の直書き厳禁
API キー、パスワード、特定のマシン固有の環境変数は、メインの設定ファイル（`.zshrc` など）に絶対に記述しないでください。
- **対応方法**: `~/.config/zsh/hidden/` 内に `.zsh` ファイルを作成し、そこに記述するよう設計されています（`.gitignore` 済み）。

### 4. べき等性（Idempotency）の担保
スクリプトは何度実行しても同じ状態になるよう設計してください。
- **シンボリックリンク**: 常に `ln -snf` を使用し、安全に上書きする。
- **ファイルへの追記**: `grep -q` などを用いて、既に同じ設定が追記済みでないか確認してから書き込む。

## アーキテクチャ概要

### アプリケーションとツールの管理
- **Homebrew**: `Brewfile` に一元管理（Formula, Cask, VS Code extensions）。
- **mise**: `.config/mise/config.toml` にて言語（Node.js, Python, Go, Java 等）を管理。`setup.sh` 実行時に `mise trust` と `mise install` を自動実行。
- **opam**: OCaml 環境。`setup.sh` 内で初期化を自動化。

## よく使うタスク（ユーザーへの提案用）

### 安全な実行シミュレーション（ドライラン）
```bash
./setup.sh --dry-run

```

※スクリプトの修正を提案した後は、本番実行の前にこのコマンドでパスの展開結果を確認するようユーザーに促してください。

### 新しいマシンのセットアップ（本番）

```bash
cd ~/dotfiles
chmod +x setup.sh
./setup.sh

```

### パッケージリスト (Brewfile) の更新

```bash
brew install <package-name>
cd ~/dotfiles
brew-dump

```

## CI / 自動テスト (GitHub Actions) に関するコンテキスト

このリポジトリは GitHub Actions (`.github/workflows/test.yaml`) により、クリーンな macOS 環境でのインストールテストを行っています。

* `setup.sh` はデフォルトの `~/dotfiles` ではなく、CI環境の `$PWD` を `DOTFILES_DIR` として受け取り実行されます。
* `mise` 実行時の GitHub API レート制限エラー（403 Forbidden）を回避するため、CI環境から `GITHUB_TOKEN` が注入されています。
* `set -e` が有効なため、コマンドの終了コードが `0` 以外になると CI が即座に失敗します。`grep` による検索など、仕様として非ゼロを返す可能性のある処理は `|| true` 等で適切にハンドリングしてください。
