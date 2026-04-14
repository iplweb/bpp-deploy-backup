# bpp-deploy-backup

[![CI](https://github.com/iplweb/bpp-deploy-backup/actions/workflows/ci.yml/badge.svg)](https://github.com/iplweb/bpp-deploy-backup/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

Jednoplikowy skrypt shellowy do pobierania pełnej kopii zapasowej instalacji
[BPP](https://github.com/iplweb/bpp-deploy) ze zdalnego hosta na maszynę
lokalną.

## Co jest pakowane

Skrypt łączy się przez SSH z podanym hostem, odczytuje `~/bpp-deploy/.env`
i streamuje pojedyncze archiwum `tar.gz` zawierające:

1. `~/bpp-deploy/` — repozytorium deploy (pliki compose, `Makefile`, `.env`)
2. Katalog wskazany przez zmienną `BPP_CONFIGS_DIR` z `~/bpp-deploy/.env` —
   konfiguracje instancji, sekrety, override'y compose, dane stanu

Archiwum trafia na maszynę lokalną (nigdy nie powstaje plik pośredni na
zdalnym hoście), pod nazwą
`backup-<host>-<compose_project>-<YYYYMMDD-HHMMSS>.tar.gz`.

## Wymagania

- `ssh` i `bash` lokalnie oraz na zdalnym hoście
- `tar` z obsługą `gzip` na zdalnym hoście
- Konto SSH na zdalnym hoście z dostępem odczytu do `~/bpp-deploy` i do
  katalogu wskazanego przez `BPP_CONFIGS_DIR`
- Po stronie zdalnej oczekiwana jest struktura zgodna z
  [iplweb/bpp-deploy](https://github.com/iplweb/bpp-deploy):
  `~/bpp-deploy/.env` z `BPP_CONFIGS_DIR=` oraz (opcjonalnie)
  `COMPOSE_PROJECT_NAME=`

## Użycie

```bash
./bpp-backup.sh <host-ssh>
```

Przykłady:

```bash
./bpp-backup.sh deploy@bpp.uczelnia.pl
./bpp-backup.sh publikacje-test        # alias z ~/.ssh/config
```

Efekt: `./backup-deploy_bpp.uczelnia.pl-publikacje-20260414-115300.tar.gz`
w bieżącym katalogu.

Inspekcja powstałego archiwum:

```bash
tar -tzf backup-*.tar.gz | head
```

Ścieżki w archiwum zaczynają się od `bpp-deploy/` oraz od nazwy katalogu
configs (bez prefiksu `/home/<user>/`).

## Jak to działa

1. Pierwsze wywołanie `ssh` odczytuje `BPP_CONFIGS_DIR` i
   `COMPOSE_PROJECT_NAME` z `~/bpp-deploy/.env` (fallback na
   `basename "$BPP_CONFIGS_DIR"`, zgodnie z konwencją z `.env.sample` w
   `bpp-deploy`).
2. Drugie wywołanie uruchamia na zdalnym hoście
   `tar -czf - -C "$HOME" bpp-deploy -C "$CONFIGS_PARENT" "$CONFIGS_BASE"`
   i zapisuje strumień lokalnie do pliku `.partial`.
3. Po sukcesie `.partial` jest przemianowywany na ostateczną nazwę.
   `trap EXIT` sprząta `.partial` przy błędzie.

## Przywracanie

Archiwum jest zwykłym `tar.gz` — przywracanie to ręczny proces:

```bash
# Do pustego katalogu:
mkdir restore && cd restore
tar -xzf /sciezka/do/backup-host-projekt-TS.tar.gz
# Otrzymasz: bpp-deploy/  <nazwa-configs>/
```

Następnie katalogi należy umieścić z powrotem w `$HOME/bpp-deploy` oraz
w miejscu wskazywanym przez `BPP_CONFIGS_DIR` na docelowym hoście.

## Licencja

MIT — zobacz [LICENSE](./LICENSE). Copyright © 2026 Michał Pasternak.
