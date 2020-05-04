#!/usr/bin/python3
"""Set Roundup admin password and email

Option:
    --pass=     unless provided, will ask interactively
    --email=    unless provided, will ask interactively
    --domain=   unless provided, will ask interactively
                DEFAULT=www.example.com
"""

import os
import sys
import getopt
import inithooks_cache
import hashlib

from dialog_wrapper import Dialog
from mysqlconf import MySQL
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

    hashpass = "{SHA}" + hashlib.sha1(password.encode('utf8')).hexdigest()

    m = MySQL()
    m.execute('UPDATE roundup._user SET _address=%s WHERE _username=\"admin\";', (email,))
    m.execute('UPDATE roundup._user SET _password=%s WHERE _username=\"admin\";', (hashpass,))

    conf = "/etc/roundup/tracker-config.ini"
    subprocess.run(["sed", "-i", "s|^web =.*|web = https://%s/|" % domain, conf])

    apache_conf = "/etc/apache2/sites-available/roundup.conf"
    subprocess.run(["sed", "-i", "\|RewriteRule|s|https://.*|https://%s/\$1 [R,L]|" % domain, apache_conf])
    subprocess.run(["sed", "-i", "\|RewriteCond|s|!^.*|!^%s$|" % domain, apache_conf])

    subprocess.run(['service', 'apache2', 'restart'])
    

if __name__ == "__main__":
    main()

