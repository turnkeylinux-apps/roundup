#!/bin/bash
set -Eeuo pipefail

old_version=2.5.0
new_version=2.6.0
venv=/tmp/roundup-upgrade-venv
tracker=/tmp/roundup-upgrade-tracker

if [[ $(id -u) -ne 0 ]]; then
    echo 'v19-upgrade.sh must run as root in a disposable Trixie container' >&2
    exit 2
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update >/dev/null
apt-get install -y --no-install-recommends \
    ca-certificates python3 python3-venv >/dev/null
python3 -m venv "$venv"

artifact() {
    python3 - "$1" <<'PYTHON'
import json
import sys
import urllib.request

version = sys.argv[1]
with urllib.request.urlopen(
        f'https://pypi.org/pypi/roundup/{version}/json') as response:
    metadata = json.load(response)
sdist = next(item for item in metadata['urls']
             if item['packagetype'] == 'sdist')
print(sdist['url'], sdist['digests']['sha256'])
PYTHON
}

read -r old_url old_sha < <(artifact "$old_version")
read -r new_url new_sha < <(artifact "$new_version")
"$venv/bin/python" -m pip install --no-deps \
    "roundup @ $old_url#sha256=$old_sha" >/dev/null
test "$("$venv/bin/python" -c 'import roundup; print(roundup.__version__)')" = \
    "$old_version"

mkdir "$tracker"
"$venv/bin/roundup-admin" -i "$tracker" install classic sqlite \
    admin_email=admin@example.com,dispatcher_email=admin@example.com,tracker_web=http://localhost/,mail_domain=example.com,mail_host=localhost \
    >/dev/null
"$venv/bin/roundup-admin" -i "$tracker" initialise upgrade-pass
issue=$("$venv/bin/roundup-admin" -i "$tracker" -u admin:upgrade-pass \
    create issue title='survives Roundup upgrade' priority=3 status=1 \
    assignedto=1)
test -n "$issue"
test "$("$venv/bin/roundup-admin" -i "$tracker" -u admin:upgrade-pass \
    get title "issue$issue")" = 'survives Roundup upgrade'

"$venv/bin/python" -m pip install --no-deps --upgrade \
    "roundup @ $new_url#sha256=$new_sha" >/dev/null
test "$("$venv/bin/python" -c 'import roundup; print(roundup.__version__)')" = \
    "$new_version"
"$venv/bin/roundup-admin" -i "$tracker" migrate
test "$("$venv/bin/roundup-admin" -i "$tracker" -u admin:upgrade-pass \
    get title "issue$issue")" = 'survives Roundup upgrade'
"$venv/bin/roundup-admin" -i "$tracker" -u admin:upgrade-pass \
    set "issue$issue" title='updated after Roundup upgrade' status=5
test "$("$venv/bin/roundup-admin" -i "$tracker" -u admin:upgrade-pass \
    get title "issue$issue")" = 'updated after Roundup upgrade'

printf 'roundup_upgrade=%s_to_%s issue=%s create_read_update=pass\n' \
    "$old_version" "$new_version" "$issue"
