#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
README_PATH="${REPO_ROOT}/README.md"
MESSAGES_PATH="${REPO_ROOT}/.github/motd/messages.txt"

if [[ ! -f "${README_PATH}" ]]; then
  echo "README.md not found: ${README_PATH}" >&2
  exit 1
fi

if [[ ! -f "${MESSAGES_PATH}" ]]; then
  echo "messages.txt not found: ${MESSAGES_PATH}" >&2
  exit 1
fi

MESSAGES=()
while IFS= read -r LINE || [[ -n "${LINE}" ]]; do
  [[ -z "${LINE}" ]] && continue
  MESSAGES+=("${LINE}")
done < "${MESSAGES_PATH}"

COUNT="${#MESSAGES[@]}"
if [[ "${COUNT}" -eq 0 ]]; then
  echo "No MOTD entries found in ${MESSAGES_PATH}" >&2
  exit 1
fi

if command -v shasum >/dev/null 2>&1; then
  SEED_HEX="$(printf '%s' "$(date -u +%F)" | shasum -a 256 | awk '{print $1}')"
else
  SEED_HEX="$(printf '%s' "$(date -u +%F)" | sha256sum | awk '{print $1}')"
fi
INDEX=$(( 16#${SEED_HEX:0:8} % COUNT ))
ENTRY="${MESSAGES[INDEX]}"

if [[ "${ENTRY}" != *" || "* ]]; then
  echo "Invalid MOTD entry format at index ${INDEX}: ${ENTRY}" >&2
  exit 1
fi

DE_MESSAGE="${ENTRY%% || *}"
EN_MESSAGE="${ENTRY#* || }"

TEMP_FILE="$(mktemp)"
awk -v de="${DE_MESSAGE}" -v en="${EN_MESSAGE}" '
  BEGIN {
    in_block = 0
    replaced = 0
  }
  /<!-- MOTD:START -->/ {
    print "<!-- MOTD:START -->"
    print "> **MOTD / Message of the Day**"
    print ">"
    print "> " de
    print ">"
    print "> " en
    print "<!-- MOTD:END -->"
    in_block = 1
    replaced = 1
    next
  }
  /<!-- MOTD:END -->/ {
    in_block = 0
    next
  }
  !in_block { print }
  END {
    if (replaced == 0) {
      print ""
      print "<!-- MOTD:START -->"
      print "> **MOTD / Message of the Day**"
      print ">"
      print "> " de
      print ">"
      print "> " en
      print "<!-- MOTD:END -->"
    }
  }
' "${README_PATH}" > "${TEMP_FILE}"

mv "${TEMP_FILE}" "${README_PATH}"
echo "Updated MOTD index ${INDEX} of ${COUNT}"
