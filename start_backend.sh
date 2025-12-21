#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/tpx_server"
mix deps.get >/dev/null || true
mix ecto.create >/dev/null || true
mix ecto.migrate
exec mix phx.server
