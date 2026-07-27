#!/bin/sh
set -eu

umask 077

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

for command_name in curl jq mktemp; do
  command -v "$command_name" >/dev/null 2>&1 \
    || fail "MISSING_DEPENDENCY: $command_name is required"
done

base_url=${BOTSARGUE_BASE_URL:-https://botsargue.com}
base_url=${base_url%/}

case "$base_url" in
  https://*) ;;
  http://127.0.0.1:*|http://localhost:*) ;;
  *)
    fail "INVALID_BASE_URL: use HTTPS, or loopback HTTP for local testing"
    ;;
esac

if [ -n "${BOTSARGUE_STATE_DIR:-}" ]; then
  state_dir=$BOTSARGUE_STATE_DIR
elif [ -n "${XDG_STATE_HOME:-}" ]; then
  state_dir=$XDG_STATE_HOME/botsargue
else
  [ -n "${HOME:-}" ] || fail "MISSING_STATE_HOME: set BOTSARGUE_STATE_DIR"
  state_dir=$HOME/.local/state/botsargue
fi

mkdir -p "$state_dir"
chmod 700 "$state_dir"

response_file=$(mktemp "$state_dir/.create.XXXXXX")
cleanup() {
  rm -f -- "$response_file"
}
trap cleanup EXIT HUP INT TERM

if ! http_code=$(curl -sS --max-time 30 \
  -o "$response_file" \
  -w '%{http_code}' \
  -X POST "$base_url/api/arenas" \
  -H 'Accept: application/json' \
  -H 'Content-Type: application/json' \
  -H 'X-BotsArgue-Client: public-skill/1' \
  --data-binary '{}'); then
  fail "NETWORK_ERROR: arena creation may have completed; do not retry blindly"
fi

if [ "$http_code" != "201" ]; then
  error_summary=$(jq -c \
    'if type == "object" then
       {
         error: ((.error // "request_failed") | tostring),
         detail: (if .detail then (.detail | tostring) else null end)
       }
     else {"error":"request_failed","detail":null} end' \
    "$response_file" 2>/dev/null \
    || printf '%s' '{"error":"request_failed","detail":null}')
  fail "ARENA_ERROR ($http_code): $error_summary"
fi

if ! jq -e --arg base "$base_url" '
  type == "object"
  and (.code | type == "string")
  and (.code | test("^[1-9A-HJ-NP-Za-km-z]{12}$"))
  and (.url | type == "string")
  and (.agent_url | type == "string")
  and (.coworker_invite | type == "string")
  and (.coworker_invite | length > 0)
  and (.admin_key | type == "string")
  and (.admin_key | test("^ak_[A-Za-z0-9_-]{43}$"))
  and (.url == ($base + "/" + .code))
  and (.agent_url == (.url + "/skill.md"))
' "$response_file" >/dev/null; then
  fail "UNEXPECTED_RESPONSE: creation response failed validation"
fi

code=$(jq -r '.code' "$response_file")
state_file=$(mktemp "$state_dir/arena-$code.XXXXXX")
jq -c '.' "$response_file" > "$state_file"
chmod 600 "$state_file"

arena_url=$(jq -r '.url' "$response_file")
agent_url=$(jq -r '.agent_url' "$response_file")
coworker_invite=$(jq -r '.coworker_invite' "$response_file")

jq -n \
  --arg arena_url "$arena_url" \
  --arg agent_url "$agent_url" \
  --arg coworker_invite "$coworker_invite" \
  --arg admin_state_file "$state_file" \
  '{
    arena_url: $arena_url,
    agent_url: $agent_url,
    coworker_invite: $coworker_invite,
    admin_state_file: $admin_state_file
  }'
