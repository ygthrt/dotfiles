# Copilot Instructions for dotfiles リポジトリ

## リポジトリの目的
macOS の設定ファイルを一元管理し、シンボリックリンクと Homebrew を使用して環境セットアップを自動化するリポジトリです。新しいマシンへのセットアップを 1 つのスクリプトで再現可能にします。

## アーキテクチャ概要

### シンボリックリンクベースの設定管理
- **設計**: 設定ファイルは `~/dotfiles/` に保存され、標準的な場所（`~/.zshrc`、`~/.config/zsh/` など）にシンボリックリンクされる
- **メリット**: すべての設定の単一情報源、バージョン管理が容易、新しいマシンへのクローンが簡単
- **主要な場所**:
  - `~/.zshrc` → `dotfiles/.zshrc`
  - `~/.config/zsh/.zshrc` → `dotfiles/.config/zsh/.zshrc`
  - `~/.config/starship.toml` → `dotfiles/.config/starship.toml`
  - `~/.config/ghostty/config` → `dotfiles/.config/ghostty/config`
  - `~/.config/zsh/hidden` → `dotfiles/.config/zsh/hidden`（機密情報用、gitignore対象）

### Homebrew パッケージ管理
- **Brewfile**: 管理対象のすべてのパッケージ（formula、cask、VS Code拡張機能）をリスト化
- **更新方法**: 新しいパッケージをインストール後、`brew bundle dump -f` で自動更新
- **setup.sh**: `brew bundle` を実行してすべてのパッケージをインストール

### 自動セットアップの流れ
`setup.sh` は以下の順序でセットアップを実行：
1. 必要なディレクトリを作成（`~/.config/zsh`、`~/.config/ghostty`）
2. すべてのシンボリックリンクを作成（`-snf` で既存ファイルを安全に上書き）
3. Homebrew がない場合はインストール、`~/.zprofile` を設定（重複チェック付き）
4. `brew bundle` を実行してすべてのパッケージをインストール

## キーとなる規約

### 新しい設定ファイルを追加する場合
1. 設定ファイルを `~/dotfiles/` に適切な階層に配置（例: `dotfiles/.config/app/config`）
2. `setup.sh` にシンボリックリンク行を追加: `ln -snf ~/dotfiles/.config/app/config ~/.config/app/config`
3. 設定ファイルと setup.sh の変更をコミット
4. **注意**: 既存のシンボリックリンクを安全に上書きするため `ln -snf` を使用

### 機密情報とマシン固有の設定の扱い
- API キー、パスワード、ローカルのみの設定は `~/.config/zsh/hidden/` に配置
- これらのファイルは gitignore の対象（`.gitignore`: `hidden/*`、ただし `hidden/README.md` は除外）
- 新しいマシンで setup.sh を実行した後、手動でこれらのファイルを再作成
- 例: `~/.config/zsh/hidden/secrets.zsh` に機密情報を記述

### パッケージリストの更新
Homebrew で新しいパッケージをインストール後：
```bash
cd ~/dotfiles
brew bundle dump -f
```
このコマンドで `Brewfile` を現在のシステム状態で再生成します。更新された Brewfile をコミット。

### シェル設定の構造
- `~/.zshrc`（dotfiles ルート）は最小限のエントリーポイントで、`~/.config/zsh/.zshrc` をソースする
- `~/.config/zsh/.zshrc` に実際の zsh 設定を記述
- 隠しファイルは自動でソース: `~/.config/zsh/hidden/` 内のすべての `.zsh` ファイルが読み込まれる

## よく使うタスク

### セットアップスクリプトの構文確認
```bash
bash -n setup.sh
```

### 新しいマシンでセットアップを実行
```bash
cd ~/dotfiles
chmod +x setup.sh
./setup.sh
source ~/.zshrc
```

### セットアップスクリプトのドライラン（実行せずに確認）
```bash
bash -x setup.sh 2>&1 | head -50
```

### 単一のパッケージを更新
```bash
brew install package-name
brew bundle dump -f
```
その後、更新された Brewfile をコミット。

## セットアップスクリプトのロジック上の注意点
- **重複排除**: `.zprofile` への Homebrew shellenv 行は追加前に確認され、重複を防止
- **シンボリックリンクの上書き**: すべての `ln -snf` 呼び出しは既存ファイル/シンボリックリンクを安全に上書き
- **エラーハンドリング**: Homebrew インストールはリモート URL から実行、新規セットアップ時はネットワーク接続を確認
- **アーキテクチャ検出**: スクリプトは Apple Silicon（M1/M2/M3）の Homebrew パス `/opt/homebrew/bin/brew` を想定

## トラッキング対象外のファイル
- `.gitignore` で `hidden/*` 内のすべてのファイルを除外（ただし `hidden/README.md` は除外）
- `.DS_Store` はグローバルで gitignore 対象
- Homebrew インストール自体はトラッキング対象ではなく、setup.sh により必要に応じてインストール
