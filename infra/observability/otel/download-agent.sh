#!/bin/sh
# OTel Java Agent를 버전과 SHA-256을 고정해 내려받는다(플랜 결정3). jar는 커밋하지 않는다(infra/.gitignore).
# 저장소 루트에서: sh infra/observability/otel/download-agent.sh
# 버전을 올리면 VERSION과 SHA256을 함께 바꾼다. SHA256은 Maven Central의 .sha256 파일 값과 대조한다.
set -eu

VERSION=2.32.0
SHA256=f787eb6c7f3d18e69a431e108a15278d25ee37f83d68b678f621e063f3988f82
URL="https://repo1.maven.org/maven2/io/opentelemetry/javaagent/opentelemetry-javaagent/${VERSION}/opentelemetry-javaagent-${VERSION}.jar"

DIR=$(cd "$(dirname "$0")" && pwd)
DEST="$DIR/opentelemetry-javaagent.jar"
TMP="$DEST.tmp"

# jar 없이 overlay를 띄운 적이 있으면 Docker가 같은 이름의 디렉터리를 만들어 둔다. 그 안으로 옮기지 않게 멈춘다
if [ -d "$DEST" ]; then
    echo "jar 자리에 디렉터리가 있다: $DEST" >&2
    echo "비어 있는지 확인한 뒤 지우고 다시 실행한다: rmdir \"$DEST\"" >&2
    exit 1
fi

if [ -f "$DEST" ] && echo "$SHA256  $DEST" | shasum -a 256 -c - > /dev/null 2>&1; then
    echo "이미 있음: $DEST ($VERSION)"
    exit 0
fi

curl -fsSL -o "$TMP" "$URL"
if ! echo "$SHA256  $TMP" | shasum -a 256 -c - > /dev/null 2>&1; then
    rm -f "$TMP"
    echo "체크섬 불일치: $URL" >&2
    exit 1
fi
mv "$TMP" "$DEST"
echo "내려받음: $DEST ($VERSION)"
