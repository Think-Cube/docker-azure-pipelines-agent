#!/usr/bin/env bash
set -euo pipefail

image=${1:?usage: smoke.sh <image>}

run() {
  docker run --rm --entrypoint "$1" "$image" "${@:2}"
}

test "$(run id -u)" = "10001"

# The built-in agent starts, which also proves .NET finds its native dependencies such as ICU.
expected=$(run printenv AGENT_VERSION)
actual=$(run /azp/bin/Agent.Listener --version)
echo "agent $actual"
test "$actual" = "$expected"

for tool in git curl jq zip unzip; do
  run sh -c "command -v $tool" > /dev/null
done

# The entrypoint refuses to start without its configuration.
expect_failure() {
  local message=$1 out
  shift
  if out=$(docker run --rm "$@" "$image" 2>&1); then
    echo "expected the entrypoint to fail: $message"
    exit 1
  fi
  grep -q "$message" <<< "$out"
}
expect_failure "missing AZP_URL"
expect_failure "set AZP_TOKEN" -e AZP_URL=https://dev.azure.com/example
