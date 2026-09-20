#!/bin/bash
set -e

echo "========================================="
echo "  HUB-C2000PP Configurator (noVNC) v1.0.5"
echo "========================================="

OPTIONS_FILE="/data/options.json"
[ ! -f "$OPTIONS_FILE" ] && OPTIONS_FILE="/dev/null"

XVFB_PID=""
OPENBOX_PID=""
X11VNC_PID=""
WEBSOCKIFY_PID=""
CFG_PID=""

cleanup() {
    echo "[*] Останавливаем сервисы..."
    for pid in "$CFG_PID" "$WEBSOCKIFY_PID" "$X11VNC_PID" "$OPENBOX_PID" "$XVFB_PID"; do
        [ -n "$pid" ] && kill "$pid" 2>/dev/null || true
    done
    exit 0
}
trap cleanup SIGTERM SIGINT SIGQUIT

# --- Пароль VNC ---
VNC_PASS=$(jq -r '.vnc_password // empty' "$OPTIONS_FILE" 2>/dev/null || echo "")

# --- Окружение Qt ---
export DISPLAY=:99
export QT_QPA_PLATFORM=xcb
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

# ============================================================
# 0. СИНХРОНИЗАЦИЯ БИНАРНИКА И РАБОЧИЕ ДИРЕКТОРИИ
# ============================================================
WORK_DIR="/data/configurator"
echo "[0/4] Подготовка рабочей папки $WORK_DIR..."
mkdir -p "$WORK_DIR"

# Копируем бинарник из образа (обновляется при пересборке)
cp -f /opt/hub/bin/Configurator "$WORK_DIR/Configurator"
chmod +x "$WORK_DIR/Configurator"

# Создаём persistent-директории
mkdir -p "$WORK_DIR/Base"
mkdir -p "$WORK_DIR/log"

echo "       Base: $WORK_DIR/Base"
echo "       log:  $WORK_DIR/log"

# --- Xvfb ---
echo "[1/4] Запуск Xvfb..."
Xvfb :99 -screen 0 1280x800x24 -nolisten tcp &
XVFB_PID=$!
sleep 2
kill -0 "$XVFB_PID" 2>/dev/null || { echo "ERROR: Xvfb упал"; exit 1; }
echo "       Xvfb OK (PID: $XVFB_PID)"

# --- openbox ---
echo "[2/4] Запуск openbox..."
openbox --config-file /dev/null &
OPENBOX_PID=$!
sleep 1
echo "       openbox OK (PID: $OPENBOX_PID)"

# --- VNC + noVNC ---
echo "[3/4] Запуск x11vnc + websockify..."
if [ -n "$VNC_PASS" ]; then
    x11vnc -display :99 -forever -shared -rfbport 5900 \
           -passwd "$VNC_PASS" -quiet -noxdamage &
else
    x11vnc -display :99 -forever -shared -rfbport 5900 \
           -nopw -quiet -noxdamage &
fi
X11VNC_PID=$!
sleep 1
echo "       x11vnc OK (PID: $X11VNC_PID)"

websockify --web /usr/share/novnc 8080 localhost:5900 &
WEBSOCKIFY_PID=$!
sleep 1
echo "       websockify OK (PID: $WEBSOCKIFY_PID)"

# --- Configurator ---
echo "[4/4] Запуск Configurator из $WORK_DIR..."
cd "$WORK_DIR"
./Configurator &
CFG_PID=$!
sleep 2

if kill -0 "$CFG_PID" 2>/dev/null; then
    echo "       Configurator OK (PID: $CFG_PID)"
else
    echo "       ВНИМАНИЕ: Configurator не запустился!"
fi

echo "========================================="
echo "  Готово."
echo "  Открой в браузере: http://<IP_HAOS>:8080/vnc.html"
echo "  Рабочая папка: $WORK_DIR"
echo "    ├── Configurator"
echo "    ├── Base/   (настройки конфигуратора)"
echo "    └── log/    (логи)"
echo ""
echo "  Внутри Configurator сервер:"
echo "    localhost:55321  или  <IP_HAOS>:55321"
echo "========================================="

wait $CFG_PID
