#!/usr/bin/env bash
set -euo pipefail

BRANCH="${BRANCH:-main}"
INTERVAL="${INTERVAL:-60}"
COMPOSE_FILE="${COMPOSE_FILE:-compose.ec2.yml}"
REPO_DIR="${REPO_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

cd "$REPO_DIR"

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"; }

log "Watching $BRANCH every ${INTERVAL}s in $REPO_DIR (compose: $COMPOSE_FILE)"

while true; do
  if git fetch origin "$BRANCH" --quiet; then
    LOCAL=$(git rev-parse "$BRANCH")
    REMOTE=$(git rev-parse "origin/$BRANCH")

    if [ "$LOCAL" != "$REMOTE" ]; then
      log "New commit on $BRANCH: $LOCAL -> $REMOTE. Deploying."
      git checkout "$BRANCH"
      git reset --hard "origin/$BRANCH"
      docker compose -f "$COMPOSE_FILE" up -d --build
      log "Deploy finished."
    fi
  else
    log "git fetch failed; will retry."
  fi

  sleep "$INTERVAL"
done
