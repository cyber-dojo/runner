#!/usr/bin/env bash
set -Eeu

export ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
rm -rf "${ROOT_DIR}/reports/rubocop" &> /dev/null || true
mkdir -p "${ROOT_DIR}/reports/rubocop"

docker run \
  --rm \
  --volume "${ROOT_DIR}/reports/rubocop/:/reports/" \
  --volume "${ROOT_DIR}:/app" \
  cyberdojo/rubocop \
  --raise-cop-error \
  --format=progress \
  --format=junit \
  --out=/reports/junit.xml
