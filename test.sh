#!/bin/bash
set -xeo pipefail

if command -v dnf > /dev/null; then
    dnf -y update
    dnf -y install gcc
fi
