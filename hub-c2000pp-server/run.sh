#!/bin/bash
set -e

echo "========================================="
echo "  HUB-C2000PP Server v1.0.2"
echo "========================================="

OPTIONS_FILE="/data/options.json"
[ ! -f "$OPTIONS_FILE" ] && OPTIONS_FILE="/dev/null"

CONN_TYPE=$(jq -r '.connection_type // "ethernet"' "$OPTIONS_FILE")
USB_DEVICE=$(jq -r '.usb_device // empty' "$OPTIONS_FILE")

WORK_DIR="/data/hub"
SERVER_PID=""

cleanup() {
    echo "[*] Останавливаем сервер..."
    [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null || true
    pkill -f HUB-C2PP 2>/dev/null || true
    exit 0
}
trap cleanup SIGTERM SIGINT SIGQUIT

# --- Очистка предыдущих процессов ---
echo "[0/4] Очистка предыдущих процессов..."
pkill -f HUB-C2PP 2>/dev/null || true
sleep 1

# ============================================================
# 1. СИНХРОНИЗАЦИЯ БИНАРНИКА
# ============================================================
echo "[1/4] Синхронизация бинарника в $WORK_DIR..."
mkdir -p "$WORK_DIR"

cp -f /opt/hub/bin/HUB-C2PP "$WORK_DIR/HUB-C2PP"
chmod +x "$WORK_DIR/HUB-C2PP"

# ============================================================
# 2. СОЗДАНИЕ РАБОЧИХ ДИРЕКТОРИЙ (persistent)
# ============================================================
echo "[2/4] Создание рабочих директорий..."
mkdir -p "$WORK_DIR/Events"
mkdir -p "$WORK_DIR/log"

echo "       Events: $WORK_DIR/Events"
echo "       log:    $WORK_DIR/log"

# ============================================================
# 3. ПОДГОТОВКА ПОРТА (для USB-режима)
# ============================================================
if [ "$CONN_TYPE" = "usb" ]; then
    echo "[3/4] Режим USB-RS485"

    if [ -z "$USB_DEVICE" ] || [ "$USB_DEVICE" = "null" ]; then
        echo "       ОШИБКА: connection_type=usb, но usb_device не выбран!"
        echo "       Зайди в Configuration аддона и выбери устройство."
        exit 1
    fi

    if [ ! -e "$USB_DEVICE" ]; then
        echo "       ОШИБКА: устройство $USB_DEVICE не найдено!"
        exit 1
    fi

    ln -sf "$USB_DEVICE" /dev/ttyBOLID 2>/dev/null \
      || ln -sf "$USB_DEVICE" /tmp/ttyBOLID

    echo "       Порт: $USB_DEVICE → /dev/ttyBOLID"
    export HUB_SERIAL_PORT="/dev/ttyBOLID"
else
    echo "[3/4] Режим Ethernet — настройка Roger в Configurator (VNC)"
fi

# ============================================================
# 4. ЗАПУСК СЕРВЕРА
# ============================================================
echo "[4/4] Запуск HUB-C2PP из $WORK_DIR..."
cd "$WORK_DIR"
./HUB-C2PP &
SERVER_PID=$!
sleep 5

if kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "       HUB-C2PP OK (PID: $SERVER_PID)"
else
    echo "       ВНИМАНИЕ: HUB-C2PP не запустился!"
    exit 1
fi

echo "========================================="
echo "  Сервер запущен."
echo "  Рабочая папка: $WORK_DIR"
echo "    ├── HUB-C2PP"
echo "    ├── Events/   (события)"
echo "    └── log/      (логи)"
echo "  Порты: TCP 55321 | UDP 22000, 22001"
echo "========================================="

# --- Перезапуск при падении ---
while true; do
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
        echo "[!] HUB-C2PP завершился, перезапуск через 10 секунд..."
        sleep 10
        cd "$WORK_DIR"
        ./HUB-C2PP &
        SERVER_PID=$!
    fi
    sleep 5
done
