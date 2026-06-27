# 設計方針

このリポジトリは、macOS の開発環境を再セットアップしやすい形で管理することを目的にしています。

一度だけ動く設定ではなく、別マシンへの移行、CI、ドライランでの確認を前提にします。

確定した設計方針はこのファイルにまとめます。未確定の改善候補や将来の検討事項は [Roadmap](roadmap.md) に分けて管理します。

## 基本方針

1. べき等性

   セットアップは何度実行しても安全で、同じ状態に収束することを重視します。

2. 安全なドライラン

   `./setup.sh --dry-run` で実行予定を確認できるようにします。ファイル作成、削除、リンク作成、インストールなどの状態変更は、ドライランでは実行しません。

3. 管理責務の分離

   Homebrew、mise、opam などの役割を分け、同じツールを複数の仕組みで管理しないようにします。

4. 秘密情報を含めない

   API キー、トークン、パスワード、個人用の環境変数は Git 管理対象に含めません。

5. 後から読める構成にする

   その場しのぎの設定ではなく、後から見ても意図が分かる構成にします。コメントは「何をしているか」より「なぜそうしているか」を説明するために使います。

## setup.sh の考え方

`setup.sh` はこのリポジトリの中心的なセットアップ入口です。

システム状態を変更するコマンドは、原則として `execute_cmd`、`run_and_log`、`run_cmd` などのドライラン対応ラッパーを経由します。

対象例:

- `mkdir`
- `ln`
- `mv`
- `rm`
- `curl`
- ファイルへの追記
- 設定ファイルの生成
- パッケージインストール
- 権限変更

シンボリックリンクは、原則として `ln -snf` を使い、安全に上書きできる形にします。

ファイルへ追記する場合は、同じ内容が重複しないようにします。

```bash
grep -q 'some setting' "$file" || echo 'some setting' >> "$file"
```

`set -e` が有効な環境では、`grep` などが仕様上非ゼロを返す場合に注意します。

## 設定ファイルの配置

設定ファイルの実体は基本的にリポジトリ内に置き、macOS が読み込む場所には `setup.sh` でシンボリックリンクを作成します。

例:

- `~/.zshrc`
- `~/.config/ghostty/config`
- `~/.config/mise/config.toml`
- `~/Library/Application Support/Code/User/settings.json`

`DOTFILES_DIR` は、次の優先順で決まります。

1. 環境変数 `DOTFILES_DIR`
2. `setup.sh` の第一引数
3. `$HOME/dotfiles`

Homebrew のインストール先は、実行時にアーキテクチャから判定します。

- Apple Silicon: `/opt/homebrew`
- Intel Mac: `/usr/local`

## Codex / AI エージェント設定

Codex の最小初期設定は `.config/codex/config.toml` に置いています。

`~/.codex/config.toml` はローカル状態が混ざりやすいため、シンボリックリンクではなく初回セットアップ時にだけコピーします。既存の `~/.codex/config.toml` がある場合は上書きしません。

Codex の rules は `.config/codex/rules/default.rules` に最小 seed を置き、`~/.codex/rules/default.rules` が存在しない場合にだけコピーします。rules の `decision = "allow"` は対象コマンドを sandbox 外で承認なし実行する例外なので、原則として広い allow rule は置きません。

sandbox 内コマンドのネットワークは、rules ではなく `sandbox_workspace_write.network_access` と `features.network_proxy` で制御します。初期 seed では OpenAI / Codex 公式サイトに必要なドメインだけを allow します。

汎用の AI エージェント向け指示は `.config/codex/AGENTS.md` に置き、`setup.sh` で `~/AGENTS.md` へシンボリックリンクします。

リポジトリ直下の `AGENTS.md` は、この dotfiles リポジトリ固有の指示です。ホームの `~/AGENTS.md` は、特定リポジトリに固有の指示がない場合に使う汎用指示として扱います。

管理しないもの:

- trusted projects などのディレクトリ信頼設定
- `auth.json` などの認証情報
- logs、sessions、cache、worktrees などの実行時データ
- マシン固有の絶対パスを含む設定

## パッケージ管理

Homebrew は macOS アプリ、CLI ツール、Cask、必要に応じて VS Code 拡張を管理します。

mise は Node.js、Python、Go、Java などの言語ランタイムや開発ツールを管理します。

opam は OCaml 環境を管理します。

Homebrew で入れるべきものと mise で入れるべきものを混在させないようにします。OCaml 関連の変更では、opam と Homebrew / mise の責務が重ならないようにします。

## 秘密情報とローカル設定

Git 管理対象の設定ファイルに秘密情報を書きません。

秘密情報やマシン固有の設定は、Git 管理外の hidden 用ファイルに分離します。

```text
~/.config/zsh/hidden/
```

このディレクトリ内の `.zsh` ファイルは shell 起動時に自動的に読み込まれます。信頼できる内容だけを配置します。

## CI

GitHub Actions では、ユーザーの実環境とは異なるパス、権限、初期状態で実行されます。

そのため、次を前提にします。

- `DOTFILES_DIR` を `~/dotfiles` に固定しない
- CI の `$PWD` をリポジトリルートとして扱えるようにする
- `set -e` 環境で非ゼロ終了する可能性のある処理を安全に扱う
- CI 専用の特殊処理を増やしすぎず、実環境での自然な挙動を優先する
