#!/usr/bin/env bash
# Run every sample through the production and print the disposition of each.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"

find "$root/data/out" -name "*.hl7" -delete 2>/dev/null

for f in "$root"/data/samples/*.hl7; do
    cp "$f" "$root/data/in/"
    sleep 4
done

echo "== released =="
for f in "$root"/data/out/*.hl7; do
    [ -e "$f" ] || continue
    echo "  $(basename "$f")"
done
echo "== escalated =="
for f in "$root"/data/out/escalated/*.hl7; do
    [ -e "$f" ] || continue
    echo "  $(basename "$f")"
done
echo "== denied =="
for f in "$root"/data/out/denied/*.hl7; do
    [ -e "$f" ] || continue
    echo "  $(basename "$f")"
done

echo
echo "== audit =="
docker compose exec -T iris iris session IRIS -U CONSENTGATE <<'EOF'
Set rs = ##class(%SQL.Statement).%ExecDirect(,"SELECT MRN, Decision, GateResult, Released, Withheld, Confidence, LatencyMs FROM ConsentGate_Data.Decision ORDER BY ID")
While rs.%Next() { Write rs.MRN, "  ", rs.Decision, "  gate=", rs.GateResult, "  rel=", rs.Released, "  wh=", rs.Withheld, "  conf=", rs.Confidence, "  ", rs.LatencyMs, "ms", ! }
halt
EOF
