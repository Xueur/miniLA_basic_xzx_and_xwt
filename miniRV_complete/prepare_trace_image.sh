#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")"
python3 bin2coe.py software/trace/start.bin
echo "Trace image is ready."
