Roundup - Issue Tracking System
===============================

`Roundup`_ is a simple-to-use and and powerful issue-tracking system
with command-line, web and e-mail interfaces. Roundup is being used for
bug tracking and TODO list management, issue management, customer help
desk support, and sales lead tracking.

This appliance includes all the standard features in `TurnKey Core`_,
and on top of that:

- Roundup configurations:
   
   - Installed from package management. See /var/www for links to file
     paths.
   - Uses Apache2 to serve roundup (instead of roundup-server).
   - Disabled registration confirmation via email (requires mail
     server).
   - Includes Xapian full text indexer (recommended for large issue DB).
   - Includes full timezone support and documentation.

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


.. _Roundup: http://roundup.sourceforge.net
.. _TurnKey Core: http://www.turnkeylinux.org/core
