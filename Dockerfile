# syntax=docker/dockerfile:1
#
# Builds a release APK of the app in a hermetic toolchain.
# Normally driven by `just build-apk`, which writes the APK to dist/.
#
# Stages:
#   toolchain  Ubuntu + JDK + Android SDK + Flutter (pinned), pre-warmed
#   keystore   generates a debug keystore (exported once, then reused)
#   build      builds the APK from the source tree
#   export     scratch image holding only the APK, for `--output`

FROM ubuntu:24.04 AS toolchain

# Match the commit noted next to the `flutter:` constraint in pubspec.yaml.
ARG FLUTTER_REF=6995038d96ef2b723cbb45882e76600deb02c9d3
ARG ANDROID_CMDLINE_TOOLS=13114758

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk \
    FLUTTER_HOME=/opt/flutter \
    PUB_CACHE=/root/.pub-cache \
    FLUTTER_SUPPRESS_ANALYTICS=true \
    CI=true
ENV PATH=$FLUTTER_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git unzip xz-utils zip \
      build-essential pkg-config \
      openjdk-17-jdk-headless \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir -p $ANDROID_HOME/cmdline-tools \
 && curl -fsSL -o /tmp/cmdline-tools.zip \
      https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS}_latest.zip \
 && unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdline-tools \
 && mv /tmp/cmdline-tools/cmdline-tools $ANDROID_HOME/cmdline-tools/latest \
 && rm -rf /tmp/cmdline-tools /tmp/cmdline-tools.zip \
 && yes | sdkmanager --licenses >/dev/null \
 && sdkmanager --install platform-tools >/dev/null

# Same approach as tools/lib/clone-flutter-sdk.sh: a blobless clone,
# because Flutter's version calculation fails on a shallow clone.
RUN git clone --filter=blob:none -b main https://github.com/flutter/flutter $FLUTTER_HOME \
 && git -C $FLUTTER_HOME checkout --detach $FLUTTER_REF \
 && git -C $FLUTTER_HOME update-ref refs/remotes/origin/master origin/main \
 && git config --global --add safe.directory $FLUTTER_HOME \
 && flutter config --no-analytics --no-cli-animations \
 && flutter precache --android --no-ios --no-web --no-linux --no-windows --no-macos \
 && flutter --version

# Build a throwaway template app, so the Android SDK platform,
# build-tools, and NDK that this Flutter version wants get baked
# into this cached layer instead of being fetched on every build.
RUN cd /tmp \
 && flutter create --platforms=android --org com.example warmup >/dev/null \
 && cd warmup \
 && flutter build apk --release \
 && cd / && rm -rf /tmp/warmup /root/.android/debug.keystore


FROM toolchain AS keystore-gen
RUN mkdir /out \
 && keytool -genkeypair -v -keystore /out/debug.keystore \
      -storepass android -keypass android -alias androiddebugkey \
      -keyalg RSA -keysize 2048 -validity 10000 \
      -dname "CN=Android Debug,O=Android,C=US"

FROM scratch AS keystore
COPY --from=keystore-gen /out/debug.keystore /debug.keystore


FROM toolchain AS build
WORKDIR /src
COPY . .
# The debug keystore signs the APK (the release build type falls back
# to debug signing when not passed -Psigned).  Keeping it stable across
# builds lets a new APK install as an update over an old one.
RUN --mount=type=secret,id=debug_keystore,required=true \
    --mount=type=cache,target=/root/.gradle \
    --mount=type=cache,target=/root/.pub-cache \
    mkdir -p /root/.android \
 && cp /run/secrets/debug_keystore /root/.android/debug.keystore \
 && flutter pub get \
 && flutter build apk --release \
 && version=$(sed -n 's/^version: *\([^+]*\).*/\1/p' pubspec.yaml) \
 && mkdir /out \
 && cp build/app/outputs/flutter-apk/app-release.apk "/out/zulip-${version}.apk"

FROM scratch AS export
COPY --from=build /out/ /
