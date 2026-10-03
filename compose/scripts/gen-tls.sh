#!/usr/bin/env bash
# 로컬 CA와 zetty.localhost 인증서를 생성한다. 키는 compose/tls/(gitignore)에만 둔다.
set -euo pipefail
umask 077
cd "$(dirname "$0")/.."
mkdir -p tls
expected=(tls/ca.crt tls/ca.key tls/server.crt tls/server.key)
present=0
for path in "${expected[@]}"; do
  if [ -e "$path" ]; then present=$((present + 1)); fi
done
if [ "$present" -gt 0 ]; then
  for path in "${expected[@]}"; do
    if [ ! -s "$path" ]; then
      echo "TLS 파일이 일부 없거나 비어 있음: 기존 파일을 덮어쓰지 않습니다." >&2
      exit 1
    fi
  done
  echo "tls 이미 존재"
  exit 0
fi
openssl req -x509 -newkey rsa:2048 -nodes -keyout tls/ca.key -out tls/ca.crt \
  -subj "/CN=zetty-local-ca" -days 825
openssl req -newkey rsa:2048 -nodes -keyout tls/server.key -out tls/server.csr \
  -subj "/CN=zetty.localhost"
openssl x509 -req -in tls/server.csr -CA tls/ca.crt -CAkey tls/ca.key -CAcreateserial \
  -out tls/server.crt -days 825 \
  -extfile <(printf "subjectAltName=DNS:zetty.localhost,DNS:localhost,IP:127.0.0.1")
rm -f tls/server.csr
echo "tls 생성 완료: compose/tls/"
