#!/usr/bin/env bash
# Sanity checks to run inside the container after `docker compose up`.
set -u
NS=CONSENTGATE

echo "== IRIS version / namespace =="
docker compose exec -T iris iris session IRIS -U $NS <<'EOF'
write "namespace: ", $NAMESPACE, !
write "version: ", $ZVERSION, !
write "AI agent class: ", ##class(%Dictionary.ClassDefinition).%ExistsId("%AI.Agent"), !
write "AI provider class: ", ##class(%Dictionary.ClassDefinition).%ExistsId("%AI.Provider"), !
write "HL7 file service: ", ##class(%Dictionary.ClassDefinition).%ExistsId("EnsLib.HL7.Service.FileService"), !
write "HL7 file operation: ", ##class(%Dictionary.ClassDefinition).%ExistsId("EnsLib.HL7.Operation.FileOperation"), !
halt
EOF

echo "== compile ConsentGate =="
docker compose exec -T iris iris session IRIS -U $NS <<'EOF'
do $System.OBJ.LoadDir("/home/irisowner/dev/src/ConsentGate", "ck", .err)
zwrite err
halt
EOF

echo "== production status =="
docker compose exec -T iris iris session IRIS -U $NS <<'EOF'
write ##class(Ens.Director).GetProductionStatus(.name, .state), " ", name, " ", state, !
halt
EOF
