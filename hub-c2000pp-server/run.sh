#!/bin/bash
set -e

echo "========================================="
echo "  HUB-C2000PP Server v1.0.1"
echo "========================================="

OPTIONS_FILE="/data/options.json"
[ ! -f "$OPTIONS_FILE" ] && OPTIONS_FILE="/dev/null"

CONN_TYPE=$(jq -r '.connection_type // "ethernet"' "$OPTIONS_FILE")
USB_DEVICE=$(jq -r '.usb_device // empty' "$OPTIONS_FILE")

# Рабочая папка в постоянном томе
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
echo "[0/3] Очистка предыдущих процессов..."
pkill -f HUB-C2PP 2>/dev/null || true
sleep 1

# ============================================================
# 1. ОБНОВЛЕНИЕ БИНАРНИКА В ТОМЕ
# ============================================================
echo "[1/3] Синхронизация бинарника в $WORK_DIR..."
mkdir -p "$WORK_DIR"

# Копируем бинарник из образа в том (при каждой сборке — обновляется)
cp -f /opt/hub/bin/HUB-C2PP "$WORK_DIR/HUB-C2PP"
chmod +x "$WORK_DIR/HUB-C2PP"

# ВАЖНО: Base НЕ трогаем — она создаётся самим сервером и сохраняется

if [ -d "$WORK_DIR/Base" ]; then
    echo "       Папка Base найдена — настройки сохраняются"
else
    echo "       Папка Base будет создана сервером при первом запуске"
fi

if [ -d "$WORK_DIR/Events" ]; then
    echo "       Папка Events найдена — настройки сохраняются"
else
    echo "       Папка Events будет создана сервером при первом запуске"
fi

# ============================================================
# 2. ПОДГОТОВКА ПОРТА (для USB-режима)
# ============================================================
if [ "$CONN_TYPE" = "usb" ]; then
    echo "[2/3] Режим USB-RS485"

    if [ -z "$USB_DEVICE" ] || [ "$USB_DEVICE" = "null" ]; then
        echo "       ОШИБКА: connection_type=usb, но usb_device не выбран!"
        echo "       Зайди в Configuration аддона и выбери устройство."
        exit 1
    fi

    if [ ! -e "$USB_DEVICE" ]; then
        echo "       ОШИБКА: устройство $USB_DEVICE не найдено!"
        exit 1
    fi

    # Создаём симлинк на фиксированный путь
    ln -sf "$USB_DEVICE" /dev/ttyBOLID 2>/dev/null \
      || ln -sf "$USB_DEVICE" /tmp/ttyBOLID

    echo "       Порт: $USB_DEVICE → /dev/ttyBOLID"
    export HUB_SERIAL_PORT="/dev/ttyBOLID"
else
    echo "[2/3] Режим Ethernet — настройка Roger в Configurator (VNC)"
fi

# ============================================================
# 3. ЗАПУСК СЕРВЕРА
# ============================================================
echo "[3/3] Запуск HUB-C2PP из $WORK_DIR..."
cd "$WORK_DIR"
./HUB-C2PP &
SERVER_PID=$!
sleep 5

if kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "       HUB-C2PP OK (PID: $SERVER_PID)"
    echo "       Base: $WORK_DIR/Base"
else
    echo "       ВНИМАНИЕ: HUB-C2PP не запустился!"
    exit 1
fi

echo "========================================="
echo "  Сервер запущен."
echo "  Бинарник, Events и Base: $WORK_DIR"
echo "  Порты: TCP 55321 | UDP 22000, 22001"
echo "========================================="

# Перезапуск при падении
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
