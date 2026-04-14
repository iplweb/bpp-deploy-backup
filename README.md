# bpp-deploy-backup

[![CI](https://github.com/iplweb/bpp-deploy-backup/actions/workflows/ci.yml/badge.svg)](https://github.com/iplweb/bpp-deploy-backup/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

Jednoplikowy skrypt shellowy do pobierania kopii zapasowej **plików
konfiguracyjnych i uruchomieniowych** instalacji
[BPP](https://github.com/iplweb/bpp-deploy) ze zdalnego hosta na maszynę
lokalną.

## Zakres backupu

> **Uwaga:** to **nie jest** backup całego systemu ani backup danych
> aplikacji. Skrypt archiwizuje wyłącznie pliki potrzebne do odtworzenia
> **konfiguracji uruchomieniowej** instancji BPP.

Skrypt łączy się przez SSH z podanym hostem, odczytuje `~/bpp-deploy/.env`
i streamuje pojedyncze archiwum `tar.gz` zawierające:

1. `~/bpp-deploy/` — repozytorium deploy (pliki compose, `Makefile`, `.env`)
2. Katalog wskazany przez zmienną `BPP_CONFIGS_DIR` z `~/bpp-deploy/.env` —
   pliki konfiguracji instancji, sekrety, override'y compose, szablony i
   pliki środowiskowe wymagane przez `docker compose up`

### Czego backup **NIE** zawiera

- dumpu bazy PostgreSQL ani żadnych innych baz danych
- wolumenów Dockera (dane uploadów, Redis, RabbitMQ, Prometheus, Grafana,
  Solr itp.) — nawet jeśli niektóre leżą fizycznie gdzieś na zdalnym hoście,
  **skrypt ich nie rusza**
- systemu operacyjnego, `/etc`, pakietów, użytkowników
- logów aplikacji ani logów kontenerów
- obrazów Dockera (są odtwarzane z rejestru przy `docker compose pull`)

Do backupu danych (baza, wolumeny) służą osobne mechanizmy opisane
w [iplweb/bpp-deploy](https://github.com/iplweb/bpp-deploy)
(np. `docker-compose.backup.yml` / target `make backup`). Ten skrypt jest
komplementarny: pozwala odtworzyć **jak** instancja była skonfigurowana,
a nie **co** w niej było.

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
w miejscu wskazywanym przez `BPP_CONFIGS_DIR` na docelowym hoście. Po
przywróceniu uzyskuje się **gotową do uruchomienia konfigurację** — baza
danych i wolumeny muszą zostać odtworzone osobno (z własnych backupów),
zanim wystartujesz `docker compose up`.

## Licencja

MIT — zobacz [LICENSE](./LICENSE). Copyright © 2026 Michał Pasternak.
