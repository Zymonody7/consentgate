#!/usr/bin/env bash
# Run one scenario end to end and print what happened.
# Usage: ./scripts/demo.sh 001
set -euo pipefail
id="${1:-001}"
root="$(cd "$(dirname "$0")/.." && pwd)"
sample=$(ls "$root"/data/samples/${id}_*.hl7 | head -1)
name=$(basename "$sample")

echo "== dropping $name into data/in =="
cp "$sample" "$root/data/in/$name"

echo "== waiting for the production to pick it up =="
for i in $(seq 1 30); do
    if ls "$root/data/out"/*"$name" >/dev/null 2>&1 \
       || ls "$root/data/out/escalated"/*"$name" >/dev/null 2>&1 \
       || ls "$root/data/out/denied"/*"$name" >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

for dir in "$root/data/out" "$root/data/out/escalated" "$root/data/out/denied"; do
    for f in "$dir"/*"$name"; do
        [ -e "$f" ] || continue
        echo
        echo "== $(basename "$dir")/$(basename "$f") =="
        tr '\r' '\n' < "$f"
    done
done

echo
echo "== audit =="
docker compose exec -T iris iris session IRIS -U CONSENTGATE <<'EOF'
Set rs = ##class(ConsentGate.Data.Decision).Latest(5)
While rs.%Next() { Write rs.RequestID, "  ", rs.MRN, "  ", rs.Decision, "  gate=", rs.GateResult, "  conf=", rs.Confidence, "  ", rs.LatencyMs, "ms", ! }
halt
EOF
