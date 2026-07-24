#!/bin/bash
set -e
set -o pipefail

LOGFILE="$HOME/.dotfiles-setup.log"

echo "セットアップを開始します..."
echo "ログ: $LOGFILE"

# DOTFILES_DIR: 環境変数 > スクリプト引数 > デフォルト
# 引数の先頭に --dry-run を指定できるようにする
DRY_RUN=0
if [ "$1" = "--dry-run" ]; then
  DRY_RUN=1
  shift
fi

# =========================================================
# 破壊的コマンドのラッパー関数
# =========================================================
# 副作用のあるコマンド（mkdir, ln, curl, echo への追記など）を管理
# DRY_RUN=1 の場合、コマンドを表示するだけで実行しない
execute_cmd() {
  if [ "$DRY_RUN" -eq 1 ]; then
    # dry-run 表示ではコマンド置換を評価しない。特に Homebrew install の curl を実行させないため。
    printf '[DRY-RUN] %s\n' "$*"
    return 0
  else
    eval "$@"
  fi
}

# =========================================================
# 1. 必要なディレクトリの作成
# =========================================================
echo "必要なディレクトリを作成しています..."
execute_cmd "mkdir -p ~/.config/zsh"
execute_cmd "mkdir -p ~/.config/ghostty"
execute_cmd "mkdir -p \"${HOME}/Library/Application Support/Code/User\""
execute_cmd "mkdir -p ~/.config/mise"
execute_cmd "mkdir -p ~/.copilot"
execute_cmd "mkdir -p ~/.codex"
execute_cmd "mkdir -p ~/.codex/rules"

if [ -n "$DOTFILES_DIR" ]; then
  DOTFILES_DIR="$DOTFILES_DIR"
elif [ -n "$1" ]; then
  DOTFILES_DIR="$1"
else
  DOTFILES_DIR="$HOME/dotfiles"
fi

# backup utility
BACKUP_DIR="$HOME/.dotfiles-backup"
canonical_path() {
  local path="$1"
  local path_dir
  local path_base
  local physical_dir

  path_dir=$(dirname "$path")
  path_base=$(basename "$path")
  physical_dir=$(cd "$path_dir" 2>/dev/null && pwd -P) || return 1

  printf '%s/%s\n' "$physical_dir" "$path_base"
}

same_symlink_target() {
  local source="$1"
  local target="$2"
  local link_value
  local link_candidate
  local source_canonical
  local candidate_canonical

  [ -L "$target" ] || return 1

  link_value=$(readlink "$target") || return 1
  if [ "$link_value" = "$source" ]; then
    return 0
  fi

  case "$link_value" in
    /*)
      link_candidate="$link_value"
      ;;
    *)
      link_candidate="$(dirname "$target")/$link_value"
      ;;
  esac

  source_canonical=$(canonical_path "$source") || return 1
  candidate_canonical=$(canonical_path "$link_candidate") || return 1

  [ "$source_canonical" = "$candidate_canonical" ]
}

backup_path_for() {
  local target="$1"
  local timestamp="$2"
  local relative_target

  case "$target" in
    "$HOME"/*)
      relative_target="${target#"$HOME"/}"
      ;;
    *)
      relative_target="${target#/}"
      ;;
  esac

  printf '%s/%s.pre-dotfiles-%s\n' "$BACKUP_DIR" "$relative_target" "$timestamp"
}

unique_backup_path() {
  local backup_path="$1"
  local candidate="$backup_path"
  local suffix=1

  while [ -e "$candidate" ] || [ -L "$candidate" ]; do
    candidate="${backup_path}.${suffix}"
    suffix=$((suffix + 1))
  done

  printf '%s\n' "$candidate"
}

backup_existing_target() {
  local target="$1"
  local timestamp
  local backup_path
  local backup_dir

  if [ "$DRY_RUN" -eq 1 ]; then
    backup_path=$(unique_backup_path "$(backup_path_for "$target" "<timestamp>")")
    echo "[DRY-RUN] 既存の設定をバックアップ予定: $target -> $backup_path"
    return 0
  fi

  timestamp=$(date +%Y%m%d%H%M%S)
  backup_path=$(unique_backup_path "$(backup_path_for "$target" "$timestamp")")
  backup_dir=$(dirname "$backup_path")

  execute_cmd "mkdir -p \"$backup_dir\""
  execute_cmd "mv \"$target\" \"$backup_path\""
  echo "バックアップ: $target -> $backup_path"
}

link_dotfile() {
  local source="$1"
  local target="$2"

  if same_symlink_target "$source" "$target"; then
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "[DRY-RUN] スキップ: $target は既に $source へのシンボリックリンクです。"
    else
      echo "スキップ: $target は既に $source へのシンボリックリンクです。"
    fi
    return 0
  fi

  if [ -e "$target" ] || [ -L "$target" ]; then
    backup_existing_target "$target"
  fi

  execute_cmd "ln -snf \"$source\" \"$target\""
}

# dry-run helper for commands
run_cmd() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY-RUN] $*"
    return 0
  else
    eval "$@"
  fi
}

# コマンドの出力を端末に表示しつつログファイルにも保存する
run_and_log() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[DRY-RUN] %s\n' "$*"
    return 0
  fi
  echo "[RUN] $*" | tee -a "$LOGFILE"

  set +e
  eval "$@" 2>&1 | tee -a "$LOGFILE"
  status=${PIPESTATUS[0]}
  set -e

  if [ $status -ne 0 ]; then
    echo "コマンドが失敗しました: $* (exit $status)" | tee -a "$LOGFILE" >&2
    return $status
  fi
  return 0
}

SUDO_KEEPALIVE_PID=""
SUDO_SESSION_CREATED=0

# sudoers は変更せず、セットアップ中だけ sudo timestamp を維持する
ensure_sudo_session() {
  if [ "${SKIP_SUDO_KEEPALIVE:-}" = "1" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "[DRY-RUN] SKIP_SUDO_KEEPALIVE=1 のため sudo keep-alive をスキップします。"
    else
      echo "SKIP_SUDO_KEEPALIVE=1 のため sudo keep-alive をスキップします。"
    fi
    return 0
  fi

  if [ "$CI" = "true" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "[DRY-RUN] CI 環境のため sudo keep-alive をスキップします。"
    else
      echo "CI 環境のため sudo keep-alive をスキップします。"
    fi
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY-RUN] sudo 認証の事前確認と keep-alive"
    return 0
  fi

  if ! command -v sudo >/dev/null 2>&1; then
    echo "sudo が見つからないため sudo keep-alive をスキップします。"
    return 0
  fi

  if [ ! -t 0 ]; then
    echo "非対話端末のため sudo keep-alive をスキップします。"
    return 0
  fi

  if sudo -n -v 2>/dev/null; then
    echo "既存の sudo 認証を検出しました。セットアップ中だけ維持します。"
  else
    echo "Homebrew / cask のインストール中に管理者権限が必要になる場合があります。"
    echo "パスワード再入力を減らすため、ここで sudo 認証を確認します。"
    if ! sudo -v; then
      echo "sudo 認証に失敗しました。" >&2
      return 1
    fi
    SUDO_SESSION_CREATED=1
  fi

  while true; do
    sudo -n -v 2>/dev/null || exit
    sleep 60
  done &
  SUDO_KEEPALIVE_PID=$!
}

cleanup_sudo_session() {
  if [ -n "${SUDO_KEEPALIVE_PID:-}" ]; then
    kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
    wait "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
  fi

  if [ "${SUDO_SESSION_CREATED:-0}" -eq 1 ]; then
    sudo -k 2>/dev/null || true
  fi
}

on_error() {
  rc=$?
  echo "エラー発生: exit $rc" >&2
  echo "最後の20行 ($LOGFILE):" >&2
  if [ -f "$LOGFILE" ]; then
    tail -n 20 "$LOGFILE" >&2
  fi
  exit $rc
}

trap 'on_error' ERR
trap 'cleanup_sudo_session' EXIT

# =========================================================
# 2. シンボリックリンクの作成
# =========================================================
echo "シンボリックリンクを作成しています..."
link_dotfile "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"

link_dotfile "$DOTFILES_DIR/.config/zsh/.zshrc" "$HOME/.config/zsh/.zshrc"

# hidden は機密情報用（gitignore済み）
link_dotfile "$DOTFILES_DIR/.config/zsh/hidden" "$HOME/.config/zsh/hidden"

link_dotfile "$DOTFILES_DIR/.config/starship/starship.toml" "$HOME/.config/starship.toml"

link_dotfile "$DOTFILES_DIR/.config/ghostty/config" "$HOME/.config/ghostty/config"

link_dotfile "$DOTFILES_DIR/vscode/settings.json" "$HOME/Library/Application Support/Code/User/settings.json"

link_dotfile "$DOTFILES_DIR/vscode/keybindings.json" "$HOME/Library/Application Support/Code/User/keybindings.json"

link_dotfile "$DOTFILES_DIR/.config/mise/config.toml" "$HOME/.config/mise/config.toml"
# mise trust は mise が利用可能になってから実行する（brew bundle 後）

link_dotfile "$DOTFILES_DIR/.config/nvim" "$HOME/.config/nvim"

link_dotfile "$DOTFILES_DIR/.copilot/copilot-instructions.md" "$HOME/.copilot/copilot-instructions.md"

link_dotfile "$DOTFILES_DIR/.config/codex/AGENTS.md" "$HOME/.codex/AGENTS.md"

# Codex config はローカル状態が混ざりやすいため、初回だけ seed を配置する
CODEX_CONFIG_TARGET="$HOME/.codex/config.toml"
if [ -e "$CODEX_CONFIG_TARGET" ] || [ -L "$CODEX_CONFIG_TARGET" ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY-RUN] Codex config は既に存在するためスキップします: $CODEX_CONFIG_TARGET"
  else
    echo "Codex config は既に存在するためスキップします: $CODEX_CONFIG_TARGET"
  fi
else
  execute_cmd "cp \"$DOTFILES_DIR/.config/codex/config.toml\" \"$CODEX_CONFIG_TARGET\""
fi

# Codex rules は sandbox 外実行の例外なので、初回だけ最小 seed を配置する
CODEX_RULES_TARGET="$HOME/.codex/rules/default.rules"
if [ -e "$CODEX_RULES_TARGET" ] || [ -L "$CODEX_RULES_TARGET" ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY-RUN] Codex rules は既に存在するためスキップします: $CODEX_RULES_TARGET"
  else
    echo "Codex rules は既に存在するためスキップします: $CODEX_RULES_TARGET"
  fi
else
  execute_cmd "cp \"$DOTFILES_DIR/.config/codex/rules/default.rules\" \"$CODEX_RULES_TARGET\""
fi

# =========================================================
# 3. Homebrew のインストールとパス設定
# =========================================================
echo "Homebrew の状態を確認しています..."
# Homebrew プレフィクスをアーキテクチャに応じて決定
ARCH=$(uname -m || true)
if [ "$ARCH" = "arm64" ]; then
  BREW_PREFIX="/opt/homebrew"
else
  BREW_PREFIX="/usr/local"
fi

if ! command -v brew &> /dev/null; then
    echo "Homebrew が見つからないため、インストールします..."
    ensure_sudo_session
    execute_cmd "/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    
    # インストール後、適切な shellenv を ~/.zprofile に追記（重複チェックあり）
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "[DRY-RUN] ~/.zprofile への Homebrew shellenv の追記チェック"
      echo "[DRY-RUN] eval \"\$($BREW_PREFIX/bin/brew shellenv)\" を追記予定"
    else
      if ! grep -q "eval \"$($BREW_PREFIX/bin/brew shellenv)\"" ~/.zprofile 2>/dev/null; then
        execute_cmd "echo 'eval \"\$($BREW_PREFIX/bin/brew shellenv)\"' >> ~/.zprofile"
      fi
    fi
    
    # shellenv を eval（ドライラン時はスキップ）
    if [ "$DRY_RUN" -eq 0 ]; then
      eval "$($BREW_PREFIX/bin/brew shellenv)"
    fi
else
    echo "Homebrew は既にインストールされています。スキップします。"
fi

# =========================================================
# 4. Brewfile からアプリとツールのインストール
# =========================================================
# Brewfile は必要なツールとアプリの存在を保証するために使う。
# セットアップ中の一斉更新で自己更新型アプリと競合しないよう、既存パッケージは更新しない。
echo "Brewfile からアプリをインストールしています..."
cd "$DOTFILES_DIR"
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY-RUN] cd $DOTFILES_DIR"
  echo "[DRY-RUN] HOMEBREW_NO_AUTO_UPDATE=1 brew bundle check --no-upgrade --verbose"
  echo "[DRY-RUN] 必要な依存関係がある場合のみ sudo 認証の事前確認と keep-alive"
  echo "[DRY-RUN] 不足がある場合のみ HOMEBREW_NO_AUTO_UPDATE=1 brew bundle install --no-upgrade --verbose"
else
  if [ "$CI" = "true" ]; then
    # CI環境では、GUIアプリ（cask）、Macアプリ（mas）、VS Code拡張機能（vscode）を除外してパイプで渡す
    run_and_log "cat Brewfile | grep -E -v '^(cask|mas|vscode)' | HOMEBREW_NO_AUTO_UPDATE=1 brew bundle install --no-upgrade --verbose --file=-" || { echo "brew bundle に失敗しました" >&2; exit 1; }
  else
    # ローカルのMacでは不足している依存関係だけをインストール
    if HOMEBREW_NO_AUTO_UPDATE=1 brew bundle check --no-upgrade --verbose; then
      echo "Brewfile の依存関係は既に満たされています。"
    else
      echo "Brewfile の依存関係に不足があります。インストール前に sudo 認証を確認します。"
      ensure_sudo_session
      run_and_log "HOMEBREW_NO_AUTO_UPDATE=1 brew bundle install --no-upgrade --verbose" || { echo "brew bundle に失敗しました" >&2; exit 1; }
    fi
  fi
fi

# =========================================================
# 5. opam (OCaml) のセットアップ
# =========================================================
echo "OCaml / opam の状態を確認しています..."

OCAML_SWITCH="default"
METAOCAML_SWITCH="metaocaml"
METAOCAML_COMPILER="ocaml-variants.5.3.0+BER"
OCAML_DEV_PACKAGES="dune ocaml-lsp-server utop ocamlformat"

opam_is_initialized() {
  opam --cli=2.1 switch list --short --safe >/dev/null 2>&1
}

opam_switch_exists() {
  local switch_name="$1"

  opam --cli=2.1 switch list --short --safe 2>/dev/null | grep -Fxq "$switch_name"
}

validate_default_ocaml_switch() {
  if opam --cli=2.1 list \
      --switch="$OCAML_SWITCH" \
      --installed \
      --short \
      base-metaocaml-ocamlfind \
      --safe 2>/dev/null | grep -Fxq "base-metaocaml-ocamlfind"; then
    echo "$OCAML_SWITCH switch が MetaOCaml 環境になっています。" >&2
    echo "通常 OCaml 用の $OCAML_SWITCH switch を別途用意してから再実行してください。" >&2
    return 1
  fi
}

validate_metaocaml_switch() {
  if ! opam --cli=2.1 list \
      --switch="$METAOCAML_SWITCH" \
      --installed \
      --short \
      "$METAOCAML_COMPILER" \
      --safe 2>/dev/null | grep -Fxq "ocaml-variants"; then
    echo "$METAOCAML_SWITCH switch は $METAOCAML_COMPILER を使用していません。" >&2
    echo "既存 switch は変更しません。名前または compiler を確認してください。" >&2
    return 1
  fi
}

if [ "${SKIP_OCAML_SETUP:-}" = "1" ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY-RUN] SKIP_OCAML_SETUP=1 のため OCaml setup をスキップ予定です。"
  else
    echo "SKIP_OCAML_SETUP=1 のため OCaml setup をスキップします。"
  fi
elif ! command -v opam &> /dev/null; then
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY-RUN] Brewfile から opam をインストールした後、次の OCaml setup を実行予定です。"
    echo "[DRY-RUN] 未初期化の場合のみ opam --cli=2.1 init --no-setup --yes"
    echo "[DRY-RUN] $OCAML_SWITCH switch がない場合のみ opam --cli=2.1 switch create $OCAML_SWITCH --packages=ocaml --yes"
    echo "[DRY-RUN] $METAOCAML_SWITCH switch がない場合のみ opam --cli=2.1 switch create $METAOCAML_SWITCH $METAOCAML_COMPILER --yes"
    echo "[DRY-RUN] opam --cli=2.1 install --switch=$OCAML_SWITCH --yes $OCAML_DEV_PACKAGES"
    echo "[DRY-RUN] opam --cli=2.1 switch set $OCAML_SWITCH"
  else
    echo "opam が見つかりません。brew bundle で opam がインストールされているか確認してください。" >&2
    exit 1
  fi
else
  if ! opam_is_initialized; then
    run_and_log "opam --cli=2.1 init --no-setup --yes"
  fi

  if opam_switch_exists "$OCAML_SWITCH"; then
    validate_default_ocaml_switch
  elif [ "$DRY_RUN" -eq 1 ] && ! opam_is_initialized; then
    echo "[DRY-RUN] opam init 後も $OCAML_SWITCH switch がない場合のみ作成予定です。"
    echo "[DRY-RUN] opam --cli=2.1 switch create $OCAML_SWITCH --packages=ocaml --yes"
  else
    run_and_log "opam --cli=2.1 switch create $OCAML_SWITCH --packages=ocaml --yes"
  fi

  if opam_switch_exists "$METAOCAML_SWITCH"; then
    validate_metaocaml_switch
  else
    run_and_log "opam --cli=2.1 switch create $METAOCAML_SWITCH $METAOCAML_COMPILER --yes"
  fi

  run_and_log "opam --cli=2.1 install --switch=$OCAML_SWITCH --yes $OCAML_DEV_PACKAGES"
  run_and_log "opam --cli=2.1 switch set $OCAML_SWITCH"
fi

# mise は brew bundle 後に存在するはずなのでここで trust と install を行う
if [ "$SKIP_MISE_INSTALL" = "1" ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY-RUN] SKIP_MISE_INSTALL=1 のため mise trust と mise install をスキップ予定です。"
  else
    echo "SKIP_MISE_INSTALL=1 のため mise trust と mise install をスキップします。"
  fi
elif [ "$DRY_RUN" -eq 0 ] && command -v mise &> /dev/null; then
  echo "mise が見つかりました。設定を信頼し、ツールの不足を確認します..."
  if [ -f "$DOTFILES_DIR/.config/mise/config.toml" ]; then
    if ! run_and_log "mise trust \"$DOTFILES_DIR/.config/mise/config.toml\""; then
      echo "mise trust に失敗しました" >&2
      exit 1
    fi

    if MISE_TERMINAL_PROGRESS=false mise install --dry-run-code --jobs=1; then
      echo "mise のツールは既にインストールされています。"
    else
      echo "mise のツールに不足があります。インストールします..."
      if ! run_and_log "MISE_TERMINAL_PROGRESS=false mise install --jobs=1"; then
        echo "mise install に失敗しました" >&2
        exit 1
      fi
    fi
  else
    echo "mise 設定ファイルが見つかりません: $DOTFILES_DIR/.config/mise/config.toml" >&2
  fi
elif [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY-RUN] mise の信頼設定とツール不足確認"
    echo "[DRY-RUN] mise trust $DOTFILES_DIR/.config/mise/config.toml"
    echo "[DRY-RUN] MISE_TERMINAL_PROGRESS=false mise install --dry-run-code --jobs=1"
    echo "[DRY-RUN] 不足がある場合のみ MISE_TERMINAL_PROGRESS=false mise install --jobs=1"
else
  echo "mise が見つかりません。brew bundle で mise がインストールされているか確認してください。" >&2
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY-RUN] すべての処理がスキップされました。実行時は --dry-run を外してください。"
else
  echo "すべてのセットアップが完了しました！ターミナルを再起動してください。"
  echo "現在のシェルへ通常 OCaml を反映する場合: eval \"\$(opam env --switch=default)\""
fi
