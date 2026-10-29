#!/usr/bin/env bash
# Sobe um host e um cliente na mesma máquina e confere a sessão online de ponta a ponta.
# Uso: GODOT=/caminho/do/godot tests/run_net_test.sh
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
export NET_PORT="${NET_PORT:-7790}"
"$GODOT" --headless --max-fps 60 --path . -s tests/net_host.gd > /tmp/net_host.log 2>&1 &
HOST=$!
sleep 2
"$GODOT" --headless --max-fps 60 --path . -s tests/net_client.gd > /tmp/net_client.log 2>&1
CLIENT_EXIT=$?
wait $HOST
HOST_EXIT=$?
grep -E "ok |FAIL|SCRIPT ERROR|HOST:|CLIENTE:" -A1 /tmp/net_host.log /tmp/net_client.log | grep -v "^--"
[ $HOST_EXIT -eq 0 ] && [ $CLIENT_EXIT -eq 0 ]
