# 運用手順

このドキュメントには、dotfiles を更新・保守するときの手順をまとめます。

## Brewfile の更新

Homebrew に新しいパッケージやアプリを追加した場合は、標準の `brew bundle dump` ではなく、このリポジトリで用意している `brew-dump` を使います。

```bash
brew install <package-name>
cd ~/dotfiles
brew-dump
```

`brew-dump` は `.config/zsh/.zshrc` で定義しています。

```bash
alias brew-dump='env PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" brew bundle dump --force'
```

通常の `brew bundle dump` をそのまま実行すると、mise や npm など別の仕組みで管理しているツールが `Brewfile` に混入することがあります。`brew-dump` は Homebrew 用の PATH に絞ってから `Brewfile` を更新します。

## Homebrew の更新

`setup.sh` は `brew bundle install --no-upgrade` を使い、Brewfile に記載されたパッケージやアプリの不足分だけを導入します。既存環境の一斉更新は行わないため、自己更新する GUI アプリとの競合や、セットアップ中の意図しないアプリ終了を避けられます。

Homebrew と既存パッケージを更新する場合は、セットアップとは分けて、更新対象を確認してから明示的に実行します。

```bash
brew update
brew outdated
brew upgrade
```

`--no-upgrade` を指定していても、新しいパッケージのインストールに必要な依存関係は更新される場合があります。

## OCaml / MetaOCaml

Homebrew は opam 本体と VS Code の OCaml Platform 拡張を管理し、OCaml の compiler と開発ツールは opam が管理します。

`setup.sh` は次の2つの switch を使います。

```text
default
  通常 OCaml
  dune / ocaml-lsp-server / utop / ocamlformat

metaocaml
  ocaml-variants.5.3.0+BER
```

既存の `default` switch の compiler は自動で変更しません。`default` が存在しない新規環境では、opam が選ぶ標準 compiler で作成します。

MetaOCaml は通常の shell 環境を切り替えず、専用関数から起動します。

```bash
# REPL またはスクリプト実行
metaocaml
metaocaml example.ml

# bytecode / native compiler
metaocamlc -o example.byte example.ml
metaocamlopt -o example.native example.ml
```

これらは内部で `opam exec --switch=metaocaml -- ...` を使うため、終了後も親 shell の switch は `default` のままです。

通常 OCaml プロジェクトでは Dune の watch mode を使うと、LSP が参照するビルド情報を更新できます。

```bash
dune build --watch --terminal-persistence=clear-on-rebuild
```

`ocamlformat` は導入しますが、グローバルの保存時フォーマットは無効です。プロジェクトルートに `.ocamlformat` を用意し、必要なプロジェクトだけ workspace 設定で `editor.formatOnSave` を有効にします。MetaOCaml 固有構文は通常の OCaml LSP や ocamlformat でエラーになる可能性があります。

現在の通常環境を確認します。

```bash
opam switch show
opam exec --switch=default -- ocamlc -version
opam exec --switch=default -- dune --version
opam exec --switch=default -- ocamllsp --version
opam exec --switch=default -- utop -version
opam exec --switch=default -- ocamlformat --version
```

compiler やパッケージを更新する場合は、`setup.sh` に自動 upgrade を追加せず、先に opam の解決内容を確認します。

```bash
opam update
opam upgrade --switch=default --dry-run
```

CI や一時的な確認で OCaml 構築を省略する場合は、次のように実行します。

```bash
SKIP_OCAML_SETUP=1 ./setup.sh
```

## hidden 設定

API キー、パスワード、特定のマシンでだけ使う設定は、Git 管理対象の設定ファイルには書きません。

ローカルの hidden ディレクトリに `.zsh` ファイルを作成します。

```bash
cd ~/.config/zsh/hidden
cp secrets.zsh.example secrets.zsh
```

`secrets.zsh` は Git 管理外です。必要な環境変数やローカル設定をこのファイルに書きます。

`~/.config/zsh/hidden/` 内の `.zsh` ファイルは shell 起動時に自動で読み込まれます。信頼できる内容だけを配置してください。

## public repository の確認

公開前や公開後の大きな変更時は、秘密情報やローカル状態が混ざっていないか確認します。

```bash
rg -n --hidden -i "(secret|token|password|api[_-]?key|credential|private[_-]?key)" .
git ls-files
git grep -n -I -E "(gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)" $(git rev-list --all)
```

実際の秘密情報が履歴に入っていた場合は、現在のファイルから消すだけでは不十分です。該当するキーを失効・再発行し、必要に応じて履歴の扱いを見直します。

[Roadmap](roadmap.md) を更新するときも、個人情報、内部 URL、未公開サービス名、具体的すぎる弱点や期限は書かないようにします。

## AI エージェント指示の更新

汎用の AI エージェント向け指示を変えたい場合は、`.config/codex/AGENTS.md` を編集します。`setup.sh` はこのファイルを `~/.codex/AGENTS.md` にシンボリックリンクします。

リポジトリ固有の指示は、そのリポジトリの `AGENTS.md` に書きます。`~/.codex/AGENTS.md` には、Codex で使う基本方針だけを置きます。

## Codex 設定 seed の更新

Codex の初期設定を変えたい場合は、`.config/codex/config.toml` を編集します。`setup.sh` は `~/.codex/config.toml` が存在しない場合にだけコピーし、既存のローカル設定は上書きしません。

Codex の rules seed は `.config/codex/rules/default.rules` を編集します。`setup.sh` は `~/.codex/rules/default.rules` が存在しない場合にだけコピーし、シンボリックリンクにはしません。

rules の `decision = "allow"` は、対象コマンドを sandbox 外で承認なし実行する設定です。`node`、`bash`、`curl`、`python`、`npm` などの広い allow は避け、sandbox 内ネットワークは `features.network_proxy` のドメイン allowlist で管理します。

## 新しい設定を管理対象に追加する

新しい設定ファイルを dotfiles で管理する場合は、次の順で追加します。

1. 設定ファイルをリポジトリ内の適切な場所に置く。
2. `setup.sh` にリンク作成や初回コピー処理を追加する。
3. 状態変更を伴うコマンドは、ドライラン対応ラッパーを経由させる。
4. `./setup.sh --dry-run` で実行予定を確認する。
5. 必要に応じて `./setup.sh` を実行する。

シンボリックリンクを作る場合は、原則として `ln -snf` を使います。

```bash
execute_cmd "ln -snf \"$DOTFILES_DIR/.config/example/config\" \"$HOME/.config/example/config\""
```

初回配置だけにしたい設定は、既存ファイルがない場合のみ `cp` する形にします。

## 変更後の確認

`setup.sh` や管理設定を変更した後は、まずドライランで確認します。

```bash
./setup.sh --dry-run
```

確認する内容:

- パスが正しく展開されているか
- 予期しないファイルを変更しようとしていないか
- 破壊的操作が直接実行されていないか
- 同じ処理が重複していないか

問題なければ本番実行します。

```bash
./setup.sh
```
