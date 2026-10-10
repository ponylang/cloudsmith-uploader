#!/bin/bash

set -o errexit

case "${1}" in
"release")
  REPO=releases
  ;;
"nightly")
  REPO=nightlies
  ;;
*)
  echo "invalid ponyc version"
  echo "Options:"
  echo "release"
  echo "nightly"
  exit 1
esac

pushd /tmp || exit
mkdir ponyc
wget "https://dl.cloudsmith.io/public/ponylang/${REPO}/raw/versions/latest/ponyc-x86-64-apple-darwin.tar.gz" -O ponyc.tar.gz
tar xzf ponyc.tar.gz -C ponyc --strip-components=1
mkdir corral
wget "https://dl.cloudsmith.io/public/ponylang/${REPO}/raw/versions/latest/corral-x86-64-apple-darwin.tar.gz" -O corral.tar.gz
tar xzf corral.tar.gz -C corral --strip-components=1
popd || exit
