#!/bin/bash

set -euo pipefail

APP="${1:?usage: smoke-test.sh <app> <executable>}"
EXECUTABLE_NAME="${2:?missing executable name}"
before=" $( (pgrep -x "$EXECUTABLE_NAME" 2>/dev/null || true) | tr '\n' ' ') "

open -n "$APP"
sleep 3

new_pid=""
while IFS= read -r pid; do
  [[ -n "$pid" ]] || continue
  if [[ "$before" != *" $pid "* ]]; then
    new_pid="$pid"
    break
  fi
done < <(pgrep -x "$EXECUTABLE_NAME" 2>/dev/null || true)

if [[ -z "$new_pid" ]]; then
  echo "error: $EXECUTABLE_NAME did not remain running" >&2
  exit 1
fi

kill -TERM "$new_pid"
echo "Smoke-tested $APP (pid $new_pid)"
