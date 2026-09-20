FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    libqt5core5a \
    libqt5gui5 \
    libqt5network5 \
    libqt5widgets5 \
    libqt5serialbus5 \
    libqt5serialport5 \
    libqt5qml5 \
    libqt5charts5 \
    libqt5quick5 \
    libqt5svg5 \
    libqt5x11extras5 \
    libxcb-xinerama0 \
    libxcb-cursor0 \
    libxcb-icccm4 \
    libxcb-image0 \
    libxcb-keysyms1 \
    libxcb-randr0 \
    libxcb-render-util0 \
    libxcb-shape0 \
    libxkbcommon-x11-0 \
    libcrypto++8 \
    libstdc++6 \
    libc6 \
    libjpeg62-turbo \
    ffmpeg \
    gnuplot \
    xvfb \
    x11vnc \
    novnc \
    websockify \
    openbox \
    ca-certificates \
    bash \
    coreutils \
    jq \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# Симлинк index.html -> vnc.html для websockify
RUN ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html

COPY bin/ /opt/hub/bin/
RUN chmod +x /opt/hub/bin/Configurator

COPY run.sh /
RUN chmod +x /run.sh

LABEL \
  io.hass.version="1.0.5" \
  io.hass.type="app" \
  io.hass.arch="aarch64|amd64"

CMD [ "/run.sh" ]
