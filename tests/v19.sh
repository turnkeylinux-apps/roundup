#!/bin/bash
set -Eeuo pipefail
umask 077

result=${TKL_TEST_RESULT:?TKL_TEST_RESULT is required}
app_password=${TKL_TEST_APP_PASS:?TKL_TEST_APP_PASS is required}
base=https://localhost
cookie=/tmp/tkl-roundup-cookie.$$
page=/tmp/tkl-roundup-page.$$
headers=/tmp/tkl-roundup-headers.$$
policy=/tmp/tkl-roundup-policy.$$

report_error() {
    printf 'test_failure line=%s status=%s command=%q\n' \
        "$1" "$2" "$3" >&2
    exit "$2"
}
trap 'report_error "$LINENO" "$?" "$BASH_COMMAND"' ERR

cleanup() {
    rm -f -- "$cookie" "$page" "$headers" "$policy"
}
trap cleanup EXIT

csrf_token() {
    sed -n '/name="@csrf"/{N;s/.*name="@csrf"[^>]*value="\([^"]*\)".*/\1/p;q}' \
        "$1"
}

systemctl --quiet is-active apache2.service mariadb.service postfix.service \
    multi-user.target
systemctl --quiet is-enabled apache2.service mariadb.service postfix.service
apache2ctl -t
apache2ctl -M 2>/dev/null | grep -F ' wsgi_module ' >/dev/null

roundup_version=$(/home/roundup/venv/bin/python -c \
    'import roundup; print(roundup.__version__)')
python_version=$(/home/roundup/venv/bin/python -c \
    'import platform; print(platform.python_version())')
test "$roundup_version" = 2.6.0
[[ $python_version == 3.13.* ]]
/home/roundup/venv/bin/python - <<'PYTHON'
import MySQLdb
import pytz
from roundup.cgi.wsgi_handler import RequestDispatcher

assert MySQLdb.__file__.startswith('/usr/lib/python3/dist-packages/')
assert pytz.__file__.startswith('/usr/lib/python3/dist-packages/')
assert RequestDispatcher
PYTHON
dpkg-query -S /usr/lib/python3/dist-packages/MySQLdb \
    /usr/lib/python3/dist-packages/pytz >/dev/null

curl --insecure --fail --silent --show-error --location \
    http://localhost/ >"$page"
grep -q 'Roundup issue tracker' "$page"
grep -q 'Roundup docs' "$page"
curl --insecure --fail --silent --show-error \
    "$base/docs/" >"$page"
grep -qi '<title>Roundup' "$page"

curl --insecure --fail --silent --show-error \
    -c "$cookie" "$base/" >"$page"
csrf=$(csrf_token "$page")
test -n "$csrf"
curl --insecure --fail --silent --show-error \
    -b "$cookie" -c "$cookie" "$base/" \
    --data-urlencode '__login_name=admin' \
    --data-urlencode "__login_password=$app_password" \
    --data-urlencode '@action=Login' \
    --data-urlencode "@csrf=$csrf" \
    --data-urlencode '__came_from=https://localhost/' >"$page"
grep -q 'Welcome+admin' "$page"
grep -q roundup_session "$cookie"

curl --insecure --fail --silent --show-error \
    -b "$cookie" "$base/issue?@template=item" >"$page"
csrf=$(csrf_token "$page")
test -n "$csrf"
curl --insecure --silent --show-error \
    -b "$cookie" -c "$cookie" -D "$headers" -o "$page" \
    "$base/issue" \
    -F 'title=TurnKey v19 acceptance issue' \
    -F 'priority=3' -F 'status=1' -F 'assignedto=1' \
    -F '@note=Created through the Roundup web interface' \
    -F '@template=item' -F '@required=title,priority' \
    -F "@csrf=$csrf" -F '@action=new'
grep -q '^HTTP/.* 302' "$headers"
issue=$(sed -n 's|^[Ll]ocation: .*\/issue\([0-9][0-9]*\).*|\1|p' \
    "$headers" | tr -d '\r')
test -n "$issue"

curl --insecure --fail --silent --show-error \
    -b "$cookie" "$base/issue$issue?@template=item" >"$page"
grep -q 'value="TurnKey v19 acceptance issue"' "$page"
csrf=$(csrf_token "$page")
test -n "$csrf"
curl --insecure --silent --show-error \
    -b "$cookie" -c "$cookie" -D "$headers" -o "$page" \
    "$base/issue$issue" \
    -F 'title=TurnKey v19 acceptance issue updated' \
    -F 'priority=3' -F 'status=5' -F 'assignedto=1' \
    -F '@note=Updated through the Roundup web interface' \
    -F '@template=item' -F '@required=title,priority' \
    -F "@csrf=$csrf" -F '@action=edit'
grep -q '^HTTP/.* 302' "$headers"
curl --insecure --fail --silent --show-error \
    -b "$cookie" "$base/issue$issue?@template=item" >"$page"
grep -q 'value="TurnKey v19 acceptance issue updated"' "$page"
mariadb --batch --skip-column-names --execute \
    "SELECT _title FROM roundup._issue WHERE id=$issue" |
    grep -Fxq 'TurnKey v19 acceptance issue updated'

dpkg-query -W webmin-apache webmin-mysql >/dev/null
curl --insecure --fail --silent --show-error --head \
    https://127.0.0.1:12321/ >/dev/null
ss -ltn | grep -Eq '127\.0\.0\.1:25[[:space:]]'

read -r pypi_candidate pypi_sdist_sha < <(
    python3 - <<'PYTHON'
import json
import urllib.request

with urllib.request.urlopen('https://pypi.org/pypi/roundup/json') as response:
    metadata = json.load(response)
version = metadata['info']['version']
artifacts = metadata['releases'][version]
sdist = next(item for item in artifacts if item['packagetype'] == 'sdist')
print(version, sdist['digests']['sha256'])
PYTHON
)
test -n "$pypi_candidate"
test -n "$pypi_sdist_sha"
/home/roundup/venv/bin/python - <<'PYTHON'
import importlib.metadata
import json

distribution = importlib.metadata.distribution('roundup')
direct_url = json.loads(distribution.read_text('direct_url.json'))
assert direct_url['url'].startswith('https://files.pythonhosted.org/')
assert direct_url['archive_info']['hash'] == (
    'sha256=12fd8fb806047415f22131f965c6ab4026a28dc63f7054e055c8f891950591d4'
)
PYTHON
test -x /usr/local/sbin/roundup-update

apache_version=$(dpkg-query -W -f='${Version}' apache2)
mariadb_version=$(dpkg-query -W -f='${Version}' mariadb-server)
python_package=$(dpkg-query -W -f='${Version}' python3)
before="$apache_version|$mariadb_version|$python_package"
apt-get update >/dev/null
for package in apache2 mariadb-server python3 python3-mysqldb python3-tz; do
    apt-cache policy "$package" >"$policy"
    candidate=$(awk '/Candidate:/ {print $2}' "$policy")
    test -n "$candidate"
    test "$candidate" != '(none)'
    grep -Eq 'trixie|deb13' "$policy"
done
after="$(dpkg-query -W -f='${Version}' apache2)|$(dpkg-query -W -f='${Version}' mariadb-server)|$(dpkg-query -W -f='${Version}' python3)"
test "$after" = "$before"
grep -Rqs '^Suites: trixie' /etc/apt/sources.list.d
! grep -Rqi bookworm /etc/apt/sources.list.d

cat >"$result" <<EOF
package_source=Debian 13 Trixie APT repositories for Python, Apache, mod_wsgi, MariaDB, Postfix and Python database/timezone modules; verified official PyPI source distribution for Roundup
installed_version=roundup $roundup_version; python $python_version ($python_package); apache2 $apache_version; mariadb-server $mariadb_version
runtime_checks=normal init; Apache, MariaDB and Postfix supervision; HTTPS Roundup and local documentation; administrator web login; web issue create, read and update with MariaDB readback; Webmin HTTPS management endpoint
updater_command=apt-get update and apt-cache policy for Debian packages; PyPI JSON candidate query; roundup-update VERSION for a supervised Roundup upgrade
updater_result=signed Debian metadata refreshed with installed packages unchanged; official PyPI candidate $pypi_candidate with sdist SHA-256 $pypi_sdist_sha; installed direct URL hash verified
updater_channel=Debian and TurnKey Trixie APT repositories; official Roundup project releases on PyPI
integrity_evidence=APT accepted signed repository metadata; installed Roundup direct_url records the pinned files.pythonhosted.org sdist and SHA-256; PyPI candidate exposes an sdist digest; no Bookworm source remained
EOF
