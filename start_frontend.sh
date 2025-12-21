#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/tpx_client"
exec npm run dev
