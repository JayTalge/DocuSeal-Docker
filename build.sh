#!/bin/sh
# Builds docuseal-jt:<version>-<rev> = upstream release tag + patches/*.patch,
# using the upstream Dockerfile (assets are rebuilt with yarn/shakapacker).
# Usage: ./build.sh 3.3.3 [jt1]
set -eu
V=${1:?upstream version, e.g. 3.3.3}
REV=${2:-jt1}
cd "$(dirname "$0")"
rm -rf src
git clone -q --depth 1 --branch "$V" https://github.com/docusealco/docuseal.git src
cd src
git -c user.name="DocuSeal-Docker build" -c user.email=build@localhost \
  am -q --3way ../patches/*.patch || {
  echo "!! patches do not apply to $V - see README.md (Updating)"; exit 1; }
docker build --pull -t "docuseal-jt:$V-$REV" .
echo "OK: docuseal-jt:$V-$REV"
