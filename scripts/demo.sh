#!/usr/bin/env bash
set -euo pipefail
BASE_URL="${1:-http://localhost:8080}"
PAYLOAD='{"clientId":"cliente123","clientName":"Comercial Demo","concept":"Servicio de soporte","amount":35000,"date":"2026-11-04"}'
response=$(curl -fsS -X POST "${BASE_URL}/api/documents" -H 'Content-Type: application/json' -d "$PAYLOAD")
echo "$response" | python3 -m json.tool
client=$(echo "$response" | python3 -c 'import json,sys; print(json.load(sys.stdin)["clientId"])')
date=$(echo "$response" | python3 -c 'import json,sys; print(json.load(sys.stdin)["date"])')
file=$(echo "$response" | python3 -c 'import json,sys; print(json.load(sys.stdin)["filename"])')
curl -fsS "${BASE_URL}/api/documents/${client}/${date}/${file}" -o /tmp/cdy2204-demo.pdf
echo "Documento descargado: /tmp/cdy2204-demo.pdf"
