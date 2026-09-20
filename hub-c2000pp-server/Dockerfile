FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    libqt5core5a \
    libqt5network5 \
    libqt5serialbus5 \
    libqt5serialport5 \
    libqt5qml5 \
    libqt5charts5 \
    libcrypto++8 \
    libstdc++6 \
    libc6 \
    libjpeg62-turbo \
    ffmpeg \
    gnuplot \
    socat \
    netcat-openbsd \
    ca-certificates \
    bash \
    coreutils \
    jq \
    tzdata \
    psmisc \
    && rm -rf /var/lib/apt/lists/*

# Бинарник сервера
COPY bin/ /opt/hub/bin/
RUN chmod +x /opt/hub/bin/HUB-C2PP

# Файлы интеграции для автокопирования в /config/custom_components/
COPY integration/ /opt/hub/integration/

# Скрипт запуска
COPY run.sh /
RUN chmod +x /run.sh

LABEL \
  io.hass.version="1.0.5" \
  io.hass.type="app" \
  io.hass.arch="aarch64|amd64"

CMD [ "/run.sh" ]
