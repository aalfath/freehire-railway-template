#!/bin/sh
# Small source patches applied to upstream's cmd/server/main.go at build time.
# Fails the build if upstream changed the lines, so a version bump never ships unpatched.
set -e
f="$1"
sed -i 's|AppName:      "hire",|AppName: "hire", Network: "tcp",|' "$f"
sed -i 's|"192.168.0.0/16", "127.0.0.1/32"}|"192.168.0.0/16", "127.0.0.1/32", "fc00::/7", "::1/128"}|' "$f"
grep -q 'Network: "tcp"' "$f"
grep -q '"fc00::/7"' "$f"
echo "patched $f"
