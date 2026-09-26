#!/bin/sh
# 로컬 KMS 에뮬레이터에 RSA 서명키와 고정 alias를 멱등 생성한다.
# 키 material은 kms /data 볼륨에만 생성되며 Git에는 저장하지 않는다.
set -e
KMS="http://kms:8080/"
ALIAS="alias/zetty-jwt-signing"
call() { wget -qO- --header="Content-Type: application/x-amz-json-1.1" \
  --header="X-Amz-Target: TrentService.$1" --post-data="$2" "$KMS"; }

for i in $(seq 1 30); do call ListKeys '{}' >/dev/null 2>&1 && break; sleep 1; done

if call ListAliases '{}' | grep -q "$ALIAS"; then
  echo "alias 이미 존재: $ALIAS"; exit 0
fi
KID=$(call CreateKey '{"KeySpec":"RSA_2048","KeyUsage":"SIGN_VERIFY"}' \
  | sed -n 's/.*"KeyId":"\([^"]*\)".*/\1/p')
echo "created key: $KID"
call CreateAlias "{\"AliasName\":\"$ALIAS\",\"TargetKeyId\":\"$KID\"}" >/dev/null
echo "alias 생성: $ALIAS"
