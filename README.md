# dotfiles

設定ファイルとアプリを管理・自動化するリポジトリです。

以下は、新しいパソコン(何もない状態)をセットアップする際の自分用のメモです。

## OS別セットアップ事前準備

### Mac (macOS) の場合

#### 1. コマンドラインツールのインストール

以下のコマンドを実行してコマンドラインツールをインストールします。

```bash
xcode-select --install
```

##### 2. GitHub 認証用トークン（PAT）の取得(sshしないといけないかもなので要検討)

SafariのプライベートウィンドウでGitHubにログインし、Personal Access Token（PAT）を取得してコピーしておいてください。


#### 3. リポジトリのクローン

ホームディレクトリ（~/）に移動し、以下のコマンドを実行してリポジトリをクローンします（既定では ~/dotfiles にクローンします）。

```bash
cd ~/
git clone https://github.com/ygthrt/dotfiles.git
```

別の場所にクローンしたい場合は、環境変数 DOTFILES_DIR を使うか、setup.sh 実行時に第一引数で指定できます（優先順: 環境変数 > スクリプト引数 > デフォルト）。例:

```bash
# 環境変数を使う
export DOTFILES_DIR="$HOME/my-dotfiles"
cd "$HOME/my-dotfiles"
chmod +x setup.sh
./setup.sh

# またはスクリプト引数を使う
cd "$HOME"
git clone https://github.com/ygthrt/dotfiles.git "$HOME/my-dotfiles"
cd "$HOME/my-dotfiles"
chmod +x setup.sh
./setup.sh "$HOME/my-dotfiles"
```

> **注記**: パスワードを求められた場合は、前述で取得したGitHub認証用トークン（PAT）を使用してください。

#### 4. 自動化スクリプトの実行

スクリプト実行前に必ず既存の設定のバックアップを取ってください（推奨バックアップ先: ~/.dotfiles-backup/）。スクリプトは既存ファイルを上書きするため、バックアップを推奨します。

例:

```bash
# バックアップ（任意）
mkdir -p ~/.dotfiles-backup
# 実行例（既定の場所）
cd ~/dotfiles
chmod +x setup.sh
./setup.sh

# 環境変数で DOTFILES_DIR を指定する例
export DOTFILES_DIR="$HOME/my-dotfiles"
./setup.sh
```

スクリプトには --dry-run モードが用意されており（一覧表示のみ）、実際に変更を適用する前に何が上書きされるかを確認できます。


#### 5. ターミナルの再起動

すべての設定が終わったら、設定ファイルを再読み込みします。

```bash
source ~/.zshrc
```

### Windows (WSL) の場合

※ 後日追記予定


---

## 運用・保守メモ（このリポジトリの仕組み）

今後の環境更新や、なぜこの構成になっているかを思い出すためのメモです。

### 1. シンボリックリンクによる一元管理

#### 対応アーキテクチャ
このリポジトリと setup.sh は macOS (Intel と Apple Silicon) 向けに設計されています。Homebrew のインストール先はアーキテクチャにより異なります：

- Apple Silicon (arm64): /opt/homebrew
- Intel (x86_64): /usr/local

setup.sh は実行時にアーキテクチャを検出し、適切な Homebrew プレフィクスを使用して shellenv を設定します。
設定ファイルの実体は基本的に `~/dotfiles` 内に配置し、Macが本来読み込む場所（`~/.zshrc` や `~/.config/ghostty/config` など）には、`setup.sh` を使って**シンボリックリンク（ショートカット）**を張る設計になっています。

例外として、Codex の `~/.codex/config.toml` はシンボリックリンクではなく、初回セットアップ時にだけ `.config/codex/config.toml` をコピーします。Codex の設定ファイルには trusted projects、認証情報、ログ、セッション、キャッシュ、ローカル絶対パスを含む状態が混ざりやすいため、既存の `~/.codex/config.toml` がある場合は上書きしません。

**【新しい設定を管理対象に加える手順】**
1. 設定ファイルを `~/dotfiles` 内の適切な階層に移動する。
2. `setup.sh` に `ln -snf ~/dotfiles/[ファイルパス] ~/.config/[ファイルパス]` のように追記する。初回配置だけにしたい設定は、既存ファイルがない場合のみ `cp` する。
3. GitでコミットしてPushする。

### 2. アプリやVS Code拡張機能の自動管理 (Brewfile)
Homebrewでインストールしたコマンドラインツール、Cask（EdgeなどのGUIアプリ）、および VS Code の拡張機能は、すべて `Brewfile` という設計図に記録されています。

**【新しくアプリを入れた時の更新手順】**

新しくアプリやVS Codeの拡張機能をインストールした場合は、以下のコマンドを実行することで `Brewfile` を全自動で最新状態に上書き（更新）できます。
```bash
cd ~/dotfiles
brew-dump
```

**運用上のポイント：なぜ専用のエイリアスを使うのか？**

通常の brew bundle dump をそのまま実行すると、mise 等でインストールした言語系パッケージ（npm や go など）まで Homebrew の管理物として誤検知され、Brewfile に混入してしまいます（次回セットアップ時にエラーの原因となります）。

これを防ぐため、当dotfilesでは .zshrc に以下のエイリアスを設定しています。実行する一瞬だけ環境変数（PATH）をシステム標準状態に隔離することで、純粋なHomebrewの管理物のみを安全に書き出す仕組みになっています。

**※エイリアスの定義内容(`.zshrc`に記載)**

```bash
alias brew-dump='env PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" brew bundle dump --force'
```

### 3. Codex の初期設定（初回配置のみ）

Codex の最小初期設定は `.config/codex/config.toml` に置いています。`setup.sh` は `~/.codex/config.toml` が存在しない場合のみコピーし、既に存在する場合はスキップします。

このリポジトリでは、以下のようなローカル状態は管理しません。

* trusted projects などのディレクトリ信頼設定
* `auth.json` などの認証情報
* logs、sessions、cache、worktrees などの実行時データ
* マシン固有の絶対パスを含む設定

### 4. 機密情報の安全な隔離（hidden フォルダ）
APIキー、パスワード、特定のPCでしか使わない特殊な設定などは、GitHubに絶対にアップロードしない仕組みを作っています。

* 場所: ~/.config/zsh/hidden/

* 仕組み: このフォルダの中に secrets.zsh などのファイルを作成して設定を書き込みます。.gitignore の効果により、このフォルダ内のファイルは Git の監視から外れ、安全にローカルのみに留まります（ダミーの README.md だけが同期されます）。

* 新規セットアップ時の注意:
新しいMacで ./setup.sh を実行した直後、この hidden フォルダの中身は空っぽです。セットアップ完了後に手動でパスワード等のファイルを再作成する必要があります。
