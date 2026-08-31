#!/usr/bin/python3
"""Set Roundup admin password and email

Option:
    --pass=     unless provided, will ask interactively
    --email=    unless provided, will ask interactively
    --domain=   unless provided, will ask interactively
                DEFAULT=www.example.com
"""

import sys
import getopt
from libinithooks import inithooks_cache

from libinithooks.dialog_wrapper import Dialog
import subprocess

def usage(s=None):
    if s:
        print("Error:", s, file=sys.stderr)
    print("Syntax: %s [options]" % sys.argv[0], file=sys.stderr)
    print(__doc__, file=sys.stderr)
    sys.exit(1)

DEFAULT_DOMAIN="www.example.com"

def main():
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], "h",
                                       ['help', 'pass=', 'email=', 'domain='])
    except getopt.GetoptError as e:
        usage(e)

    password = ""
    email = ""
    domain = ""
    for opt, val in opts:
        if opt in ('-h', '--help'):
            usage()
        elif opt == '--pass':
            password = val
        elif opt == '--email':
            email = val
        elif opt == '--domain':
            domain = val

    if not password:
        d = Dialog('TurnKey Linux - First boot configuration')
        password = d.get_password(
            "Roundup Password",
            "Enter new password for the Roundup 'admin' account.")

    if not email:
        if 'd' not in locals():
            d = Dialog('TurnKey Linux - First boot configuration')

        email = d.get_email(
            "Roundup Email",
            "Enter email address for the Roundup 'admin' account.",
            "admin@example.com")

    inithooks_cache.write('APP_EMAIL', email)

    if not domain:
        if 'd' not in locals():
            d = Dialog('TurnKey Linux - First boot configuration')

        domain = d.get_input(
            "Roundup Domain",
            "Enter the domain to serve Roundup.",
            DEFAULT_DOMAIN)

    if domain == "DEFAULT":
        domain = DEFAULT_DOMAIN

    inithooks_cache.write('APP_DOMAIN', domain)

    subprocess.run([
        "/home/roundup/venv/bin/roundup-admin",
        "-i", "/var/lib/roundup/tracker",
        "-u", "admin:turnkey",
        "set", "user1",
        "password=%s" % password,
        "address=%s" % email,
    ], check=True)

    conf = "/etc/roundup/tracker-config.ini"
    subprocess.run(["sed", "-i", "s|^web =.*|web = https://%s/|" % domain, conf], check=True)

    apache_conf = "/etc/apache2/sites-available/roundup.conf"
    subprocess.run(["sed", "-i", r"\|RewriteRule|s|https://.*|https://%s/\$1 [L,R=301]|" % domain, apache_conf], check=True)
    subprocess.run(["sed", "-i", r"\|RewriteCond|s|!^.*|!^%s$|" % domain, apache_conf], check=True)

    subprocess.run(['service', 'apache2', 'restart'], check=True)
    

if __name__ == "__main__":
    main()
