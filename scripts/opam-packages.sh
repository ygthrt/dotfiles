#!/bin/bash

# setup.sh と CI が同じ package 定義を参照し、検証対象のずれを防ぐ。
OCAML_SWITCH="default"
METAOCAML_SWITCH="metaocaml"
METAOCAML_COMPILER="ocaml-variants.5.3.0+BER"
OCAML_DEV_PACKAGES="dune ocaml-lsp-server utop ocamlformat"
METAOCAML_DEV_PACKAGES="utop"
