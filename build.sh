#!/bin/sh
# Builds docuseal-<set>:<version>-<rev> = upstream release tag + patches/<set>/*.patch,
# using the upstream Dockerfile (assets are rebuilt with yarn/shakapacker).
#
#   ./build.sh brand 3.3.6 1    # branding via env + brand pack, OIDC, hardening
#
# The patches apply cleanly to the release in patches/<set>/BASE. For a newer release
# they are applied there first and then moved with `git rebase --onto`, a real 3-way
# merge, so upstream changes next to the patched lines do not stop the build. Only
# genuine conflicts fail it (see README.md, Updating).
set -eu
SET=${1:?patch set, e.g. brand}
V=${2:?upstream version, e.g. 3.3.6}
REV=${3:-1}
cd "$(dirname "$0")"
[ -d "patches/$SET" ] || { echo "!! unknown patch set: $SET"; exit 1; }
BASE=$(cat "patches/$SET/BASE")
rm -rf src
# blobless clone with history and tags: the rebase needs BASE, V and their common history
git clone -q --filter=blob:none --no-checkout https://github.com/docusealco/docuseal.git src
cd src
git() { command git -c user.name="DocuSeal-Docker build" -c user.email=build@localhost \
  -c commit.gpgsign=false -c advice.detachedHead=false "$@"; }
git checkout -q "$BASE"
git am -q "../patches/$SET"/*.patch || {
  echo "!! patches/$SET do not apply to their base $BASE - regenerate them (README.md, Updating)"; exit 1; }
if [ "$V" != "$BASE" ]; then
  git rebase -q --onto "$V" "$BASE" || {
    echo "!! patches/$SET (base $BASE) conflict with $V:"; git diff --name-only --diff-filter=U | sed 's/^/   /'
    echo "!! resolve them as described in README.md (Updating)"; exit 1; }
  echo "patches/$SET moved from $BASE to $V without conflicts"
fi
docker build --pull \
  --label org.opencontainers.image.source=https://github.com/JayTalge/DocuSeal-Docker \
  --label org.opencontainers.image.version="$V-$REV" \
  --label org.opencontainers.image.description="DocuSeal $V + patches/$SET (github.com/JayTalge/DocuSeal-Docker)" \
  -t "docuseal-$SET:$V-$REV" .
echo "OK: docuseal-$SET:$V-$REV"
