#!/usr/bin/env bash
# Testes de rede na mesma máquina:
#  1. host + convidado: sessão online de ponta a ponta;
#  2. host + convidado com mapa adulterado: tem que ser recusado.
# Uso: GODOT=/caminho/do/godot tests/run_net_test.sh
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
export NET_PORT="${NET_PORT:-7790}"
LOGS="${TMPDIR:-/tmp}"

run_pair() {
	"$GODOT" --headless --max-fps 60 --path . -s "$1" > "$LOGS/$3.log" 2>&1 &
	local host=$!
	sleep 2
	"$GODOT" --headless --max-fps 60 --path . -s "$2" > "$LOGS/$4.log" 2>&1
	local client_exit=$?
	wait $host
	local host_exit=$?
	grep -E "ok |FAIL|SCRIPT ERROR|HOST|CLIENTE" -A1 "$LOGS/$3.log" "$LOGS/$4.log" | grep -v "^--"
	[ $host_exit -eq 0 ] && [ $client_exit -eq 0 ]
}

run_pair tests/net_host.gd tests/net_client.gd net_host net_client
FIRST=$?
run_pair tests/net_tamper_host.gd tests/net_tamper_client.gd net_tamper_host net_tamper_client
SECOND=$?
[ $FIRST -eq 0 ] && [ $SECOND -eq 0 ]
