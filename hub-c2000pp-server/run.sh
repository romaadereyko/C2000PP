#!/bin/bash
set -e

echo "========================================="
echo "  HUB-C2000PP Server v1.0.3"
echo "========================================="

OPTIONS_FILE="/data/options.json"
[ ! -f "$OPTIONS_FILE" ] && OPTIONS_FILE="/dev/null"

CONN_TYPE=$(jq -r '.connection_type // "ethernet"' "$OPTIONS_FILE")
USB_DEVICE=$(jq -r '.usb_device // empty' "$OPTIONS_FILE")
AUTO_INSTALL=$(jq -r '.auto_install_integration // "true"' "$OPTIONS_FILE")

WORK_DIR="/data/hub"
INTEGRATION_SRC="/opt/hub/integration/hubc2000pp"
INTEGRATION_DST="/config/custom_components/hubc2000pp"

SERVER_PID=""

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
# 1. АВТОУСТАНОВКА ИНТЕГРАЦИИ В HOME ASSISTANT
# ============================================================
echo "[1/5] Проверка интеграции hubc2000pp в Home Assistant..."

if [ "$AUTO_INSTALL" = "true" ]; then
    if [ ! -d "$INTEGRATION_SRC" ]; then
        echo "       ВНИМАНИЕ: папка $INTEGRATION_SRC не найдена в образе."
        echo "       Проверь, что файлы интеграции скопированы в integration/hubc2000pp/"
    elif [ -d "$INTEGRATION_DST" ]; then
        # Интеграция уже есть — обновляем файлы (могут быть новее в аддоне)
        echo "       Интеграция уже установлена — обновляем файлы..."
        cp -rf "$INTEGRATION_SRC/." "$INTEGRATION_DST/"
        echo "       Обновлено: $INTEGRATION_DST"
    else
        # Первая установка
        echo "       Интеграция не найдена — устанавливаем..."
        mkdir -p /config/custom_components
        cp -rf "$INTEGRATION_SRC" "$INTEGRATION_DST"
        echo "       Установлено: $INTEGRATION_DST"
        echo ""
        echo "       ⚠️  ПЕРЕЗАГРУЗИ HOME ASSISTANT, чтобы интеграция появилась в Настройки → Устройства и службы"
    fi
else
    echo "       Автоустановка отключена (auto_install_integration: false)"
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

echo "========================================="
echo "  Сервер запущен."
echo "  Рабочая папка: $WORK_DIR"
echo "    ├── HUB-C2PP"
echo "    ├── Events/   (события)"
echo "    └── log/      (логи)"
echo "  Порты: TCP 55321 | UDP 22000, 22001"
echo ""
echo "  Если интеграция установлена впервые —"
echo "  ПЕРЕЗАГРУЗИ Home Assistant."
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
