#!/usr/bin/env bash
#
# bpp-backup.sh — pobiera lokalnie kopię zapasową instancji BPP ze zdalnego hosta.
#
# Backup obejmuje:
#   - $HOME/bpp-deploy na zdalnym hoście
#   - katalog wskazany przez BPP_CONFIGS_DIR z $HOME/bpp-deploy/.env
#
# Wynik: ./backup-<host>-<compose_project>-<YYYYMMDD-HHMMSS>.tar.gz
#
# Użycie: ./bpp-backup.sh <host-ssh>

set -euo pipefail

if [ "$#" -lt 1 ] || [ -z "${1:-}" ]; then
    echo "Użycie: $0 <host-ssh>" >&2
    echo "Przykład: $0 deploy@bpp.uczelnia.pl" >&2
    exit 1
fi

HOST="$1"

echo "==> Odczytuję ~/bpp-deploy/.env z ${HOST}..." >&2

remote_env=$(ssh "$HOST" 'bash -s' <<'REMOTE'
set -euo pipefail
ENV_FILE="$HOME/bpp-deploy/.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "ERR: brak $ENV_FILE na zdalnym hoscie" >&2
    exit 1
fi

get() {
    grep -E "^$1=" "$ENV_FILE" | tail -n1 | cut -d= -f2- \
        | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/"
}

BPP_CONFIGS_DIR=$(get BPP_CONFIGS_DIR)
COMPOSE_PROJECT_NAME=$(get COMPOSE_PROJECT_NAME)

if [ -z "$BPP_CONFIGS_DIR" ]; then
    echo "ERR: BPP_CONFIGS_DIR puste w $ENV_FILE" >&2
    exit 1
fi
if [ ! -d "$BPP_CONFIGS_DIR" ]; then
    echo "ERR: katalog $BPP_CONFIGS_DIR nie istnieje na zdalnym hoscie" >&2
    exit 1
fi

if [ -z "$COMPOSE_PROJECT_NAME" ]; then
    COMPOSE_PROJECT_NAME=$(basename "$BPP_CONFIGS_DIR")
fi

printf 'BPP_CONFIGS_DIR=%s\n' "$BPP_CONFIGS_DIR"
printf 'COMPOSE_PROJECT_NAME=%s\n' "$COMPOSE_PROJECT_NAME"
REMOTE
)

BPP_CONFIGS_DIR=$(printf '%s\n' "$remote_env" | sed -n 's/^BPP_CONFIGS_DIR=//p')
COMPOSE_PROJECT_NAME=$(printf '%s\n' "$remote_env" | sed -n 's/^COMPOSE_PROJECT_NAME=//p')

if [ -z "$BPP_CONFIGS_DIR" ] || [ -z "$COMPOSE_PROJECT_NAME" ]; then
    echo "ERR: nie udało się odczytać zmiennych ze zdalnego .env" >&2
    exit 1
fi

echo "    BPP_CONFIGS_DIR=${BPP_CONFIGS_DIR}" >&2
echo "    COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME}" >&2

TS=$(date +%Y%m%d-%H%M%S)
HOST_TAG=$(printf '%s' "$HOST" | tr '@:/' '___')
OUT="./backup-${HOST_TAG}-${COMPOSE_PROJECT_NAME}-${TS}.tar.gz"
PARTIAL="${OUT}.partial"

trap 'rm -f "$PARTIAL"' EXIT

echo "==> Pakuję zdalnie i pobieram do ${OUT}..." >&2

# shellcheck disable=SC2087  # heredoc celowo niesquotowane: ${BPP_CONFIGS_DIR}
# rozwija się lokalnie, a \$HOME / \$CONFIGS_DIR na zdalnym hoście.
ssh "$HOST" 'bash -s' > "$PARTIAL" <<REMOTE_TAR
set -euo pipefail
CONFIGS_DIR="${BPP_CONFIGS_DIR}"
CONFIGS_PARENT=\$(dirname "\$CONFIGS_DIR")
CONFIGS_BASE=\$(basename "\$CONFIGS_DIR")
# Każde -C zmienia katalog roboczy tar-a, więc w archiwum zapisujemy
# wyłącznie nazwy bazowe (bpp-deploy/, <configs>/) bez prefiksu /home/...
tar -czf - \\
    -C "\$HOME" bpp-deploy \\
    -C "\$CONFIGS_PARENT" "\$CONFIGS_BASE"
REMOTE_TAR

if [ ! -s "$PARTIAL" ]; then
    echo "ERR: pusty plik backupu — coś poszło nie tak po stronie SSH/tar" >&2
    exit 1
fi

mv "$PARTIAL" "$OUT"
trap - EXIT

echo "==> Gotowe: ${OUT}" >&2
du -h "$OUT" >&2
