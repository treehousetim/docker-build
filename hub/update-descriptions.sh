#!/usr/bin/env bash
# Push the Docker Hub short description + overview for each repo from the
# hub/<repo>.md files. The short description is the line inside the leading
# <!-- --> comment; the overview is everything after it.
#
#   ./hub/update-descriptions.sh                 # all repos
#   ./hub/update-descriptions.sh php-cli-pdo     # one repo
#   DRY_RUN=1 ./hub/update-descriptions.sh       # show what would be sent
#
# Auth: a Docker Hub personal access token (Read & Write scope), from
# $DOCKERHUB_TOKEN or the file ~/.dockerhub_token.
set -euo pipefail
cd "$(dirname "$0")"

NAMESPACE="${DOCKERHUB_NAMESPACE:-treehousetim}"
USERNAME="${DOCKERHUB_USERNAME:-treehousetim}"
(( $# )) || set -- php-fpm-pdo php-cli-pdo php-fpm-pdo-xdebug

# Build {"description": ..., "full_description": ...} from a hub/*.md file.
payload() {
  python3 -I - "$1" <<'EOF'
import json, re, sys
text = open(sys.argv[1], encoding="utf-8").read()
m = re.match(r"\s*<!--.*?\n(.*?)\n-->\s*\n", text, re.S)
if not m:
    sys.exit(f"{sys.argv[1]}: missing leading <!-- short description --> comment")
short, full = m.group(1).strip(), text[m.end():]
if len(short) > 100:
    sys.exit(f"{sys.argv[1]}: short description is {len(short)} chars (max 100)")
print(json.dumps({"description": short, "full_description": full}))
EOF
}

if [[ -n "${DRY_RUN:-}" ]]; then
  for repo in "$@"; do
    payload "$repo.md" | python3 -I -c '
import json, sys
d = json.load(sys.stdin)
short, full = d["description"], d["full_description"]
print("%s: [%d] %s  (+%d char overview)" % (sys.argv[1], len(short), short, len(full)))' "$repo"
  done
  exit 0
fi

token="${DOCKERHUB_TOKEN:-$(cat ~/.dockerhub_token 2>/dev/null || true)}"
token="$(tr -d '[:space:]' <<<"$token")"
[[ -n "$token" ]] || { echo "No token: set DOCKERHUB_TOKEN or put it in ~/.dockerhub_token" >&2; exit 1; }

# Exchange the access token for a short-lived JWT. The token travels on stdin,
# never on the command line.
jwt="$(python3 -I -c 'import json,sys; print(json.dumps({"username": sys.argv[1], "password": sys.stdin.read().strip()}))' "$USERNAME" <<<"$token" \
  | curl -fsS -H 'Content-Type: application/json' --data-binary @- https://hub.docker.com/v2/users/login \
  | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["token"])')" \
  || { echo "Docker Hub login failed -- check the token and its scope (Read & Write)" >&2; exit 1; }

for repo in "$@"; do
  status="$(payload "$repo.md" | curl -sS -o /dev/null -w '%{http_code}' -X PATCH \
    -H "Authorization: Bearer $jwt" -H 'Content-Type: application/json' \
    --data-binary @- "https://hub.docker.com/v2/repositories/$NAMESPACE/$repo/")"
  if [[ "$status" == 200 ]]; then
    echo "updated  $NAMESPACE/$repo"
  else
    echo "FAILED   $NAMESPACE/$repo (HTTP $status)" >&2; exit 1
  fi
done
