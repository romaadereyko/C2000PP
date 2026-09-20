#!/bin/bash
set -e

echo "========================================="
echo "  HUB-C2000PP Server v1.0.5"
echo "========================================="

OPTIONS_FILE="/data/options.json"
[ ! -f "$OPTIONS_FILE" ] && OPTIONS_FILE="/dev/null"

CONN_TYPE=$(jq -r '.connection_type // "ethernet"' "$OPTIONS_FILE")
USB_DEVICE=$(jq -r '.usb_device // empty' "$OPTIONS_FILE")
AUTO_INSTALL=$(jq -r '.auto_install_integration // "true"' "$OPTIONS_FILE")

WORK_DIR="/data/hub"
INTEGRATION_SRC="/opt/hub/integration/hubc2000pp"
INTEGRATION_DST="/config/custom_components/hubc2000pp"
MARKER_FILE="/data/.integration_installed"

SERVER_PID=""
FIRST_INSTALL=0

cleanup() {
    echo "[*] Останавливаем сервер..."
    [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null || true
    pkill -f HUB-C2PP 2>/dev/null || true
    exit 0
}
trap cleanup SIGTERM SIGINT SIGQUIT

# ============================================================
# 0. ОЧИСТКА ПРЕДЫДУЩИХ ПРОЦЕССОВ
# ============================================================
echo "[0/5] Очистка предыдущих процессов..."
pkill -f HUB-C2PP 2>/dev/null || true
sleep 1

# ============================================================
# 1. УСТАНОВКА ИНТЕГРАЦИИ (только при первом запуске или обновлении)
# ============================================================
echo "[1/5] Проверка интеграции hubc2000pp..."

if [ "$AUTO_INSTALL" != "true" ]; then
    echo "       Автоустановка отключена (auto_install_integration: false)"
elif [ ! -d "$INTEGRATION_SRC" ]; then
    echo "       ВНИМАНИЕ: папка $INTEGRATION_SRC не найдена в образе."
    echo "       Проверь, что файлы интеграции скопированы в integration/hubc2000pp/"
elif [ ! -f "$MARKER_FILE" ]; then
    # ---------- ПЕРВАЯ УСТАНОВКА ----------
    echo "       Первая установка интеграции..."
    mkdir -p /config/custom_components
    rm -rf "$INTEGRATION_DST"
    cp -rf "$INTEGRATION_SRC" "$INTEGRATION_DST"

    # Создаём marker — при следующих запусках пойдём по ветке "обновление"
    touch "$MARKER_FILE"

    echo "       Установлено: $INTEGRATION_DST"
    FIRST_INSTALL=1
else
    # ---------- ПОВТОРНЫЙ ЗАПУСК: тихое обновление ----------
    echo "       Интеграция уже установлена — обновляем файлы..."
    cp -rf "$INTEGRATION_SRC/." "$INTEGRATION_DST/" 2>/dev/null || {
        echo "       ВНИМАНИЕ: не удалось обновить файлы интеграции."
    }
    echo "       Обновлено: $INTEGRATION_DST"
fi

# ============================================================
# 2. СИНХРОНИЗАЦИЯ БИНАРНИКА
# ============================================================
echo "[2/5] Синхронизация бинарника в $WORK_DIR..."
mkdir -p "$WORK_DIR"
cp -f /opt/hub/bin/HUB-C2PP "$WORK_DIR/HUB-C2PP"
chmod +x "$WORK_DIR/HUB-C2PP"

# ============================================================
# 3. СОЗДАНИЕ РАБОЧИХ ДИРЕКТОРИЙ
# ============================================================
echo "[3/5] Создание рабочих директорий..."
mkdir -p "$WORK_DIR/Events"
mkdir -p "$WORK_DIR/log"
echo "       Events: $WORK_DIR/Events"
echo "       log:    $WORK_DIR/log"

# ============================================================
# 4. ПОДГОТОВКА ПОРТА (для USB-режима)
# ============================================================
if [ "$CONN_TYPE" = "usb" ]; then
    echo "[4/5] Режим USB-RS485"

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
    echo "[4/5] Режим Ethernet — настройка Roger в Configurator (VNC)"
fi

# ============================================================
# 5. ЗАПУСК СЕРВЕРА
# ============================================================
echo "[5/5] Запуск HUB-C2PP из $WORK_DIR..."
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

# ============================================================
# ФИНАЛЬНЫЕ СООБЩЕНИЯ
# ============================================================
echo "========================================="
echo "  Сервер запущен."
echo "  Рабочая папка: $WORK_DIR"
echo "  Порты: TCP 55321 | UDP 22000, 22001"

if [ "$FIRST_INSTALL" = "1" ]; then
    echo ""
    echo "  ╔════════════════════════════════════════════╗"
    echo "  ║  ⚠️  ТРЕБУЕТСЯ ПЕРЕЗАГРУЗКА HOME ASSISTANT  ║"
    echo "  ╚════════════════════════════════════════════╝"
    echo ""
    echo "  Интеграция hubc2000pp установлена впервые."
    echo "  Перезагрузи HA: Настройки → Система → Перезагрузить"
    echo "  После этого добавь её:"
    echo "    Настройки → Устройства и службы → + Добавить интеграцию → hubc2000pp"
fi

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
