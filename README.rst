Roundup - Issue Tracking System
===============================

`Roundup`_ is a simple-to-use and and powerful issue-tracking system
with command-line, web and e-mail interfaces. Roundup is being used for
bug tracking and TODO list management, issue management, customer help
desk support, and sales lead tracking.

This appliance includes all the standard features in `TurnKey Core`_,
and on top of that:

- Roundup configurations:
   
   - Installed via pip into a python virtual env, within it's own user account.
     See /var/www for links to file paths.
   - Roundup served via Apache mod_python.
   - Disabled registration confirmation via email (requires mail
     server).
   - Includes Xapian full text indexer (recommended for large issue DB).
   - Includes full timezone support and documentation.

     **Security note**: Updates to Roundup may require supervision so
     they **ARE NOT** configured to install automatically. See `Roundup
     documentation`_ for upgrading. Please note specific user account and
     location of virtual env when updating.

- SSL support out of the box.
- Postfix MTA (bound to localhost) to allow sending of email
  (e.g., password recovery).
- Webmin modules for configuring Apache2, MySQL and Postfix.

Initial configuration: */etc/roundup/tracker-config.ini*

**Required settings**::

    [tracker]
    web = /                     (before)
    web = http://appliance_ip/  (after)
    # Note: If not set, links in emails will not include server address.

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


.. _Roundup: http://roundup-tracker.org/
.. _Roundup documentation: http://roundup.sourceforge.net/docs/upgrading.html
.. _TurnKey Core: https://www.turnkeylinux.org/core
