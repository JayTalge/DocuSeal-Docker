#!/bin/sh
# Builds docuseal-<set>:<version>-<rev> = upstream release tag + patches/<set>/*.patch,
# using the upstream Dockerfile (assets are rebuilt with yarn/shakapacker).
#
#   ./build.sh brand 3.3.4 b1   # generic set: branding via env + brand pack, OIDC, hardening
#   ./build.sh jt 3.3.4 1       # sign.jason-talge.de (JT branding compiled in)
set -eu
SET=${1:?patch set: brand or jt}
V=${2:?upstream version, e.g. 3.3.4}
REV=${3:-1}
cd "$(dirname "$0")"
[ -d "patches/$SET" ] || { echo "!! unknown patch set: $SET"; exit 1; }
rm -rf src
# blobless clone with history: git am --3way can merge patches across upstream changes
git clone -q --filter=blob:none --branch "$V" https://github.com/docusealco/docuseal.git src
cd src
git -c user.name="DocuSeal-Docker build" -c user.email=build@localhost -c commit.gpgsign=false \
  am -q --3way "../patches/$SET"/*.patch || {
  echo "!! patches/$SET do not apply to $V - see README.md (Updating)"; exit 1; }
docker build --pull -t "docuseal-$SET:$V-$REV" .
echo "OK: docuseal-$SET:$V-$REV"
