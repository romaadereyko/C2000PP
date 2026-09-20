#!/bin/bash
set -e

echo "========================================="
echo "  HUB-C2000PP Server"
echo "========================================="

SERVER_PID=""

cleanup() {
    echo "[*] Останавливаем сервер..."
    [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null || true
    pkill -f HUB-C2PP 2>/dev/null || true
    exit 0
}
trap cleanup SIGTERM SIGINT SIGQUIT

# --- Очистка от предыдущих копий ---
echo "[0/2] Очистка предыдущих процессов..."
pkill -f HUB-C2PP 2>/dev/null || true
sleep 1
rm -f /tmp/*HUB* /var/run/*HUB* 2>/dev/null || true
rm -f /opt/hub/bin/*.lock /opt/hub/bin/*.pid 2>/dev/null || true

# --- Рабочая папка в /data (постоянное хранилище) ---
mkdir -p /data/hub
cd /opt/hub/bin

# --- Запуск сервера ---
echo "[1/2] Запуск HUB-C2PP..."
./HUB-C2PP &
SERVER_PID=$!
sleep 5

if kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "       HUB-C2PP OK (PID: $SERVER_PID)"
else
    echo "       ВНИМАНИЕ: HUB-C2PP не запустился!"
    exit 1
fi

# --- Проверка портов ---
echo "[2/2] Проверка портов..."
sleep 2
netstat -tulpn 2>/dev/null | grep -E "22000|22001|55321" || true

echo "========================================="
echo "  Сервер запущен."
echo "  Порты: TCP 55321 | UDP 22000, 22001"
echo "  Конфигуратор подключается к:"
echo "    http://<IP_HAOS>:8080/vnc.html"
echo "========================================="

# --- Перезапуск при падении ---
while true; do
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
        echo "[!] HUB-C2PP завершился, перезапуск через 10 секунд..."
        sleep 10
        cd /opt/hub/bin
        ./HUB-C2PP &
        SERVER_PID=$!
    fi
    sleep 5
done
