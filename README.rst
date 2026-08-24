Roundup - Issue Tracking System
===============================

`Roundup`_ is a simple-to-use and powerful issue-tracking system
with command-line, web and e-mail interfaces. Roundup is being used for
bug tracking and TODO list management, issue management, customer help
desk support, and sales lead tracking.

This appliance includes all the standard features in `TurnKey Core`_,
and on top of that:

- Roundup configurations:
   
   - Roundup 2.6 is installed from its verified official PyPI source
     distribution in ``/home/roundup/venv``. Python, the MariaDB driver and
     timezone data are maintained through Debian Trixie packages.
   - Roundup served via Apache mod_wsgi.
   - Domain to serve, set on first boot.
   - Disabled registration confirmation via email (requires mail
     server).
   - Includes full timezone support and documentation.

     **Security note**: Roundup updates may require a tracker migration, so
     they are not installed automatically. Back up the appliance, read the
     `Roundup documentation`_, then install a selected release with::

        roundup-update VERSION

     The command obtains the release URL and SHA-256 digest from the official
     PyPI metadata, updates the deployed virtual environment, runs the Roundup
     tracker migration, and restarts Apache.


- SSL support out of the box.
- Postfix MTA (bound to localhost) to allow sending of email
  (e.g., password recovery).
- Webmin modules for configuring Apache2, MySQL and Postfix.

Initial configuration: */etc/roundup/tracker-config.ini*

**Recommended settings**::

    [main]
    admin_email = admin
    dispatcher_email = admin
    [mail]
    domain = example.com

Credentials *(passwords set at first boot)*
-------------------------------------------

-  Webmin, Webshell, SSH, MySQL: username **root**
-  Roundup: username **admin**


.. _Roundup: https://roundup-tracker.org/
.. _Roundup documentation: https://docs.roundup-tracker.org/en/latest/installation.html#upgrading
.. _TurnKey Core: https://www.turnkeylinux.org/core
