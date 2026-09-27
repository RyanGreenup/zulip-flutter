# Signed with a debug keystore kept in .apk-build/ (generated on first
# run) so that later builds install as updates over earlier ones.

# Build a release APK in Docker and write it to dist/
build-apk:
  #!/usr/bin/env bash
  set -euo pipefail
  if [ ! -f .apk-build/debug.keystore ]; then
    docker buildx build --target keystore --output type=local,dest=.apk-build .
  fi
  rm -rf dist
  docker buildx build --target export \
    --secret id=debug_keystore,src=.apk-build/debug.keystore \
    --output type=local,dest=dist .
  ls -lh dist/*.apk
