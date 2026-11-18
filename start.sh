#!/usr/bin/env bash
# Configures and runs the Azure Pipelines agent built into the image.
# Based on https://learn.microsoft.com/azure/devops/pipelines/agents/docker
#
# Environment:
#   AZP_URL             organization URL, for example https://dev.azure.com/contoso (required)
#   AZP_TOKEN           personal access token with Agent Pools (read, manage)
#   AZP_TOKEN_FILE      file with the token, instead of AZP_TOKEN
#   AZP_POOL            agent pool (default: Default)
#   AZP_AGENT_NAME      agent name (default: the container hostname)
#   AZP_WORK            work directory (default: _work)
#   AZP_REGISTER_ONLY   true to register the agent and exit, leaving it offline as a
#                       template that keeps the pool non-empty for autoscaling
# Arguments are passed to the agent, for example --once for one job per container.
set -euo pipefail

print_header() {
  printf '\n\033[1;36m%s\033[0m\n\n' "$1"
}

if [ -z "${AZP_URL:-}" ]; then
  echo "error: missing AZP_URL environment variable" >&2
  exit 1
fi

token_file=${AZP_TOKEN_FILE:-/azp/.token}
if [ -n "${AZP_TOKEN:-}" ]; then
  (umask 177 && printf '%s' "$AZP_TOKEN" > "$token_file")
elif [ ! -s "$token_file" ]; then
  echo "error: set AZP_TOKEN, or AZP_TOKEN_FILE to a readable file with the token" >&2
  exit 1
fi
unset AZP_TOKEN

# Keep the token out of the environment that jobs see.
export VSO_AGENT_IGNORE="AZP_TOKEN,AZP_TOKEN_FILE,VSTS_AGENT_INPUT_TOKEN"

agent_name=${AZP_AGENT_NAME:-$(hostname)}

# The agent reads VSTS_AGENT_INPUT_TOKEN and masks it, so the token never shows on a command line.
agent_config() {
  VSTS_AGENT_INPUT_TOKEN=$(cat "$token_file") ./config.sh "$@"
}

cleanup() {
  trap '' EXIT INT TERM
  print_header "Removing agent ${agent_name}"
  # Removal fails while a job is still running, so give it time to finish.
  for attempt in $(seq 1 10); do
    agent_config remove --unattended --auth PAT && return 0
    echo "Attempt ${attempt} failed; retrying in 30 seconds"
    sleep 30
  done
  echo "warning: could not remove agent ${agent_name}" >&2
}

cd /azp

if [ -n "${AZP_WORK:-}" ]; then
  mkdir -p "$AZP_WORK"
fi

# Records the environment the agent reports as capabilities.
bash ./env.sh

print_header "Configuring agent ${agent_name} in pool ${AZP_POOL:-Default}"
agent_config --unattended \
  --agent "$agent_name" \
  --url "$AZP_URL" \
  --auth PAT \
  --pool "${AZP_POOL:-Default}" \
  --work "${AZP_WORK:-_work}" \
  --replace \
  --acceptTeeEula

if [ "${AZP_REGISTER_ONLY:-false}" = "true" ]; then
  print_header "Registered ${agent_name}; it stays offline as a template"
  exit 0
fi

trap 'cleanup; exit 0' EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

print_header "Running agent ${agent_name}"
./run.sh "$@" &
wait $!
