# Anti-Beer Goggles Android APK builder and download service for Render.
# Push this Dockerfile and android-source.zip to the root of your GitHub repository.
FROM eclipse-temurin:17-jdk-jammy AS builder
ENV DEBIAN_FRONTEND=noninteractive \
    ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk
ENV PATH="${PATH}:/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools"
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl unzip libstdc++6 zlib1g \
    && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /opt/android-sdk/cmdline-tools \
    && curl -fL --retry 3 \
       https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip \
       -o /tmp/sdk-tools.zip \
    && unzip -q /tmp/sdk-tools.zip -d /tmp/sdk-tools \
    && mv /tmp/sdk-tools/cmdline-tools /opt/android-sdk/cmdline-tools/latest \
    && rm -rf /tmp/sdk-tools.zip /tmp/sdk-tools
RUN yes | sdkmanager --sdk_root="$ANDROID_SDK_ROOT" --licenses > /dev/null
RUN sdkmanager --sdk_root="$ANDROID_SDK_ROOT" \
      'platform-tools' 'platforms;android-35' 'build-tools;35.0.0'
WORKDIR /src
COPY android-source.zip /tmp/android-source.zip
RUN unzip -q /tmp/android-source.zip -d /src \
    && rm /tmp/android-source.zip \
    && chmod +x ./gradlew \
    && ./gradlew --no-daemon --stacktrace :app:assembleDebug \
    && test -s ./app/build/outputs/apk/debug/app-debug.apk
FROM python:3.12-slim
WORKDIR /srv/public
COPY --from=builder /src/app/build/outputs/apk/debug/app-debug.apk \
     /srv/public/Anti-Beer-Goggles-debug.apk
COPY --from=builder /src/render_index.html /srv/public/index.html
RUN useradd --system --uid 10001 --home /srv appuser \
    && chmod -R a+rX /srv/public
USER appuser
EXPOSE 10000
CMD ["sh", "-c", "exec python -m http.server ${PORT:-10000} --bind 0.0.0.0"]
