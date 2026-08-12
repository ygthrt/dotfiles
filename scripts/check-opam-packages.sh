#!/bin/bash
set -e
set -u
set -o pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=opam-packages.sh
source "$SCRIPT_DIR/opam-packages.sh"

if ! command -v opam >/dev/null 2>&1; then
  echo "opam が見つかりません。先に Brewfile の依存関係を導入してください。" >&2
  exit 1
fi

TMP_PARENT="${TMPDIR:-/tmp}"
OPAM_CHECK_ROOT=$(mktemp -d "${TMP_PARENT%/}/dotfiles-opam-check.XXXXXX")

cleanup() {
  rm -rf -- "$OPAM_CHECK_ROOT"
}
trap cleanup EXIT

# ユーザーの opam 環境から分離し、compiler をビルドせず依存解決だけを確認する。
unset OPAMSWITCH
export OPAMROOT="$OPAM_CHECK_ROOT"
export OPAMCOLOR="never"

read -r -a ocaml_dev_packages <<< "$OCAML_DEV_PACKAGES"
read -r -a metaocaml_dev_packages <<< "$METAOCAML_DEV_PACKAGES"

opam --cli=2.1 init \
  --bare \
  --disable-sandboxing \
  --no-setup \
  --yes \
  default \
  https://opam.ocaml.org

echo "$OCAML_SWITCH switch の package 解決を確認しています..."
opam --cli=2.1 switch create "$OCAML_SWITCH" --empty --yes
opam --cli=2.1 install \
  --switch="$OCAML_SWITCH" \
  --show-actions \
  --yes \
  ocaml \
  "${ocaml_dev_packages[@]}"

echo "$METAOCAML_SWITCH switch の package 解決を確認しています..."
opam --cli=2.1 switch create "$METAOCAML_SWITCH" --empty --yes
opam --cli=2.1 install \
  --switch="$METAOCAML_SWITCH" \
  --show-actions \
  --yes \
  "$METAOCAML_COMPILER" \
  "${metaocaml_dev_packages[@]}"

echo "opam package の依存解決に成功しました。"
