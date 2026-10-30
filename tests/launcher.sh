#!/usr/bin/env bash
# Runs the launcher with a stand-in frankenphp and checks that Reverb starts and stops with the server,
# and that nothing changes when Reverb isn't enabled.

set -euo pipefail
set -m

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

mkdir -p "$WORK_DIR/bundle/app/public" "$WORK_DIR/home/.koel" "$WORK_DIR/bin"
cp "$ROOT/koel" "$WORK_DIR/bundle/koel"

cat > "$WORK_DIR/bundle/frankenphp" <<FAKE
#!/usr/bin/env bash
if [[ "\$1" == php-cli && "\$3" == reverb:start ]]; then
	echo \$\$ > "$WORK_DIR/reverb.pid"

	if [[ -n "\${REVERB_EXIT_CODE:-}" ]]; then
		exit "\$REVERB_EXIT_CODE"
	fi

	trap '' TERM INT
	exec sleep 300
fi

if [[ "\$1" == php-server ]]; then
	echo \$\$ > "$WORK_DIR/server.pid"

	if [[ -n "\${SERVER_EXIT_CODE:-}" ]]; then
		sleep 1
		exit "\$SERVER_EXIT_CODE"
	fi

	trap 'exit 0' TERM
	trap '' HUP
	while :; do sleep 0.1; done
fi
FAKE

printf '#!/bin/sh\nexit 0\n' > "$WORK_DIR/bin/crontab"
chmod +x "$WORK_DIR/bundle/koel" "$WORK_DIR/bundle/frankenphp" "$WORK_DIR/bin/crontab"

failures=0

fail() {
	echo "FAIL: $1"
	failures=$((failures + 1))
}

is_running() {
	kill -0 "$1" 2>/dev/null
}

wait_for_file() {
	for _ in $(seq 1 100); do
		[[ -s "$1" ]] && return 0
		sleep 0.1
	done

	return 1
}

# Usage: run_case <name> <.env BROADCAST_CONNECTION line> <how to stop: int|term|hup|crash> <expect Reverb: yes|no|dies> [env…]
run_case() {
	local name="$1" env_line="$2" stop="$3" expect_reverb="$4" failures_before=$failures
	shift 4

	rm -f "$WORK_DIR/reverb.pid" "$WORK_DIR/server.pid"
	printf 'APP_KEY=test\n%s\n' "$env_line" > "$WORK_DIR/home/.koel/.env"

	env -u BROADCAST_CONNECTION HOME="$WORK_DIR/home" PATH="$WORK_DIR/bin:$PATH" "$@" \
		"$WORK_DIR/bundle/koel" php-server >"$WORK_DIR/launcher.log" 2>&1 &
	local launcher_pid=$!

	if ! wait_for_file "$WORK_DIR/server.pid"; then
		fail "$name: the server didn't start"
		kill -9 -- "-$launcher_pid" 2>/dev/null || true
		return
	fi

	local server_pid reverb_pid=""
	server_pid="$(cat "$WORK_DIR/server.pid")"

	if [[ "$expect_reverb" == yes ]]; then
		wait_for_file "$WORK_DIR/reverb.pid" || fail "$name: Reverb didn't start"
		reverb_pid="$(cat "$WORK_DIR/reverb.pid" 2>/dev/null || true)"
	elif [[ "$expect_reverb" == dies ]]; then
		wait_for_file "$WORK_DIR/reverb.pid" || fail "$name: Reverb didn't start"
		sleep 3
		is_running "$server_pid" || fail "$name: the server stopped along with Reverb"
	else
		sleep 0.5
		[[ -e "$WORK_DIR/reverb.pid" ]] && fail "$name: Reverb started"
		[[ "$server_pid" == "$launcher_pid" ]] || fail "$name: the server no longer replaces the launcher process"
	fi

	case "$stop" in
		int) kill -INT -- "-$launcher_pid" ;;
		term) kill -TERM "$launcher_pid" ;;
		hup)
			kill -HUP "$launcher_pid"
			sleep 1
			is_running "$launcher_pid" || fail "$name: the launcher exited on SIGHUP"
			is_running "$server_pid" || fail "$name: the server stopped on SIGHUP"
			[[ -z "$reverb_pid" ]] || is_running "$reverb_pid" || fail "$name: Reverb stopped on SIGHUP"
			kill -TERM "$launcher_pid" 2>/dev/null || true
			;;
	esac

	for _ in $(seq 1 100); do
		is_running "$launcher_pid" || break
		sleep 0.1
	done

	if is_running "$launcher_pid"; then
		fail "$name: the launcher didn't exit"
		kill -9 -- "-$launcher_pid" 2>/dev/null || true
	fi

	local status=0
	wait "$launcher_pid" || status=$?

	if [[ "$stop" == crash && $status -ne 3 ]]; then
		fail "$name: exit code $status, expected the server's 3"
	fi

	is_running "$server_pid" && fail "$name: the server is still running"
	[[ -n "$reverb_pid" ]] && is_running "$reverb_pid" && fail "$name: Reverb is still running"

	if grep -q 'Reverb stopped right after starting' "$WORK_DIR/launcher.log"; then
		[[ "$expect_reverb" == dies ]] || fail "$name: warned that Reverb stopped"
	else
		[[ "$expect_reverb" == dies ]] && fail "$name: no warning that Reverb stopped"
	fi

	kill -9 "$server_pid" ${reverb_pid:+"$reverb_pid"} 2>/dev/null || true
	if [[ $failures -eq $failures_before ]]; then
		echo "ok: $name"
	fi
}

run_case "Reverb stops on Ctrl+C" 'BROADCAST_CONNECTION=reverb' int yes
run_case "Reverb stops on SIGTERM" 'BROADCAST_CONNECTION="reverb"' term yes
run_case "Reverb with a comment after the setting" 'BROADCAST_CONNECTION=reverb # live updates' term yes
run_case "Reverb stops when the server crashes" 'BROADCAST_CONNECTION=reverb' crash yes SERVER_EXIT_CODE=3
run_case "SIGHUP leaves the server and Reverb running" 'BROADCAST_CONNECTION=reverb' hup yes
run_case "SIGHUP leaves the server running without Reverb" 'BROADCAST_CONNECTION=pusher' hup no
run_case "Warns when Reverb stops right after starting" 'BROADCAST_CONNECTION=reverb' term dies REVERB_EXIT_CODE=1
run_case "No Reverb with another broadcaster" 'BROADCAST_CONNECTION=pusher' term no
run_case "No Reverb when the environment overrides .env" 'BROADCAST_CONNECTION=reverb' term no BROADCAST_CONNECTION=null
run_case "Reverb from the environment" '' int yes BROADCAST_CONNECTION=reverb

if [[ $failures -gt 0 ]]; then
	echo "$failures check(s) failed"
	exit 1
fi
