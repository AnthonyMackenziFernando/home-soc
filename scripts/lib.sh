#!/usr/bin/env bash
# Shared helpers for Home SOC host-side scripts (setup / deploy-rules / healthcheck).
# Source this from another script:  source "$(dirname "$0")/lib.sh"

# --- paths ------------------------------------------------------------------
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LIB_DIR/.." && pwd)"
DEPLOY_DIR="$REPO_ROOT/deploy"
export REPO_ROOT DEPLOY_DIR

# --- pretty logging ---------------------------------------------------------
if [ -t 1 ]; then
  C_RESET='\033[0m'; C_RED='\033[31m'; C_GRN='\033[32m'; C_YEL='\033[33m'; C_BLU='\033[36m'
else
  C_RESET=''; C_RED=''; C_GRN=''; C_YEL=''; C_BLU=''
fi
log()  { printf "${C_BLU}[*]${C_RESET} %s\n" "$*"; }
ok()   { printf "${C_GRN}[+]${C_RESET} %s\n" "$*"; }
warn() { printf "${C_YEL}[!]${C_RESET} %s\n" "$*"; }
err()  { printf "${C_RED}[x]${C_RESET} %s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

# --- docker compose wrapper (v2 plugin or legacy binary) --------------------
DOCKER_COMPOSE=()
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  DOCKER_COMPOSE=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  DOCKER_COMPOSE=(docker-compose)
fi

# Run a compose subcommand from inside deploy/ so relative paths and .env resolve.
dc() {
  [ ${#DOCKER_COMPOSE[@]} -gt 0 ] || die "Docker Compose not found. Install Docker Engine + the compose plugin (see docs/02-setup.md)."
  ( cd "$DEPLOY_DIR" && "${DOCKER_COMPOSE[@]}" "$@" )
}

require_docker() {
  command -v docker >/dev/null 2>&1 || die "docker is not installed. See docs/02-setup.md."
  docker info >/dev/null 2>&1 || die "Cannot talk to the Docker daemon. Is it running, and is your user in the 'docker' group?"
  [ ${#DOCKER_COMPOSE[@]} -gt 0 ] || die "Docker Compose plugin not found. See docs/02-setup.md."
}
