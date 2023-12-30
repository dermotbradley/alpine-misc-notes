
/etc/passwd

| Username   | Pwd | UID   | GID   | GECOS         | Home                   | Shell          | Notes         |
|------------|-----|-------|-------|---------------|------------------------|----------------|---------------|
| root       | x   |     0 |     0 | root          | /root                  | /bin/ash       | |
| bin        | x   |     1 |     1 | bin           | /bin                   | /sbin/nologin  | |
| daemon     | x   |     2 |     2 | daemon        | /sbin                  | /sbin/nologin  | ? |
| adm        | x   |     3 |     4 | adm           | /var/adm               | /sbin/nologin  | |
| lp         | x   |     4 |     7 | lp            | /var/spool/lpd         | /sbin/nologin  | Safe to remove? Created by "cups" package. |
| sync       | x   |     5 |     0 | sync          | /sbin                  | /bin/sync      | **Safe to remove**. |
| shutdown   | x   |     6 |     0 | shutdown      | /sbin                  | /sbin/shutdown | **Safe to remove**. Not used by Alpine's Busybox init |
| halt       | x   |     7 |     0 | halt          | /sbin                  | /sbin/halt     | **Safe to remove**. Not used by Alpine's Busybox init |
| mail       | x   |     8 |    12 | mail          | /var/mail              | /sbin/nologin  | **Safe to remove**. |
| news       | x   |     9 |    13 | news          | /usr/lib/news          | /sbin/nologin  | **Safe to remove**. |
| uucp       | x   |    10 |    14 | uucp          | /var/spool/uucppublic  | /sbin/nologin  | Safe to remove? |
| operator   | x   |    11 |     0 | operator      | /root                  | /sbin/nologin  | **Safe to remove**. |
| man        | x   |    13 |    15 | man           | /usr/man               | /sbin/nologin  | Used by "man-db" package - sets files inside /var/cache/man with user "man". |
| postmaster | x   |    14 |    12 | postmaster    | /var/mail              | /sbin/nologin  | **Safe to remove**. |
| cron       | x   |    16 |    16 | cron          | /var/spool/cron        | /sbin/nologin  | ? |
| ftp        | x   |    21 |    21 |               | /var/lib/ftp           | /sbin/nologin  | **Safe to remove**. |
| sshd       | x   |    22 |    22 | sshd          | /dev/null              | /sbin/nologin  | |
| at         | x   |    25 |    25 | at            | /var/spool/cron/atjobs | /sbin/nologin  | **Safe to remove**. Busybox has no "at" support. Created by "at" package. |
| squid      | x   |    31 |    31 | Squid         | /var/cache/squid       | /sbin/nologin  | **Safe to remove**. Created by "squid" package. |
| xfs        | x   |    33 |    33 | X Font Server | /etc/X11/fs            | /sbin/nologin  | **Safe to remove**. |
| games      | x   |    35 |    35 | games         | /usr/games             | /sbin/nologin  | **Safe to remove**. |
| cyrus      | x   |    85 |    12 |               | /usr/cyrus             | /sbin/nologin  | **Safe to remove**. |
| vpopmail   | x   |    89 |    89 |               | /var/vpopmail          | /sbin/nologin  | **Safe to remove**. Not used anywhere. |
| ntp        | x   |   123 |   123 | NTP           | /var/empty             | /sbin/nologin  | **Safe to remove**. |
| smmsp      | x   |   209 |   209 | smmsp         | /var/spool/mqueue      | /sbin/nologin  | **Safe to remove**. The "milter-greylist" package creates this user. |
| guest      | x   |   405 |   100 | guest         | /dev/null              | /sbin/nologin  | **Safe to remove**. |
| nobody     | x   | 65534 | 65534 | nobody        | /                      | /sbin/nologin  | |




/etc/group

| Group    | Pwd | GID   | User List       | Notes |
|----------|-----|-------|-----------------|-------|
| root     | x   |     0 | root            | |
| bin      | x   |     1 | root,bin,daemon | |
| daemon   | x   |     2 | root,bin,daemon | |
| sys      | x   |     3 | root,bin,adm    | |
| adm      | x   |     4 | root,adm,daemon | Used for some logfiles in /var/log/. Used by "vector" package. |
| tty      | x   |     5 |                 | Used by "eudev", "mdev-conf" packages. Used for /dev/console, /dev/ptmx, /dev/tty[0-9]+, /dev/vcs[0-9]*, /dev/vcsa[0-9]+ |
| disk     | x   |     6 | root,adm        | Used for /dev/sd[a-z], /dev/sd[a-z][1-9], etc. Used by "bareos", "eudev", "mdev-conf", "prometheus-smartctl-exporter", "sanlock" packages. |
| lp       | x   |     7 | lp              | Safe to remove? Created by "cups" package. Used by "eudev" package. |
| mem      | x   |     8 |                 | |
| kmem     | x   |     9 |                 | Used by "eudev" package. |
| wheel    | x   |    10 | root            | Used for /dev/log, /var/log/messages |
| floppy   | x   |    11 | root            | Used by "bareos", "mdev-conf" packages. |
| mail     | x   |    12 | mail            | Used by "dkimproxy", "exim", "opendkim", "postfix" packages. |
| news     | x   |    13 | news            | |
| uucp     | x   |    14 | uucp            | Used for /dev/ttyS*, /run/lock. Used by "mdev-conf", "nut", "smstools" packages. |
| man      | x   |    15 | man             | Used by "man-db" package - sets files inside /var/cache/man with group "man". |
| cron     | x   |    16 | cron            | |
| console  | x   |    17 |                 | |
| audio    | x   |    18 |                 | Created by "snapcast". Used by "barkery-weston", "eudev", "kodi", "librespot", "mdev-conf", "mopidy", "pulseaudio", "sndio", "spotifyd", "svxlink", "ympd" packages. |
| cdrom    | x   |    19 |                 | Used by "bareos", "eudev", "mdev-conf" packages. |
| dialout  | x   |    20 | root            | Created by "asterisk" package. Used by "eudev", "mdev-conf", "zigbee2mqtt" packages. |
| ftp      | x   |    21 |                 | Created by "vsftpd" package. Used by "proftpd" package. |
| sshd     | x   |    22 |                 | |
| input    | x   |    23 |                 | Used by "barkery-weston", "eudev", "kodi", "mdev-conf" packages. |
| at       | x   |    25 | at              | **Safe to remove**. Busybox has no "at" support. Created by "at" package. |
| tape     | x   |    26 | root            | Used by "bareos", "eudev", "mdev-conf" packages. |
| video    | x   |    27 | root            | Used by "barkery-weston", "eudev", "greetd", "kodi", "mdev-conf", "minisatip", "motion", "sddm", "tvheadend", "vdr" packages. |
| netdev   | x   |    28 |                 | Created by "avahi" package. Used by "mdev-conf", "qemu-openrc" package. |
| readproc | x   |    30 |                 | Created by "collectd" package. Used by "netdata", "vnstat" package. |
| squid    | x   |    31 | squid           | **Safe to remove**. Created by "squid" package. |
| xfs      | x   |    33 | xfs             | **Safe to remove**. |
| kvm      | x   |    34 | kvm             | Created by "qemu" package. Used by "eudev", "mdev-conf", "qemu-openrc" package. |
| games    | x   |    35 |                 | Used by "minetest-server" package. |
| shadow   | x   |    42 |                 | Used for /etc/shadow and /etc/shadow-. Created by "alpine-baselayout" package. |
| cdrw     | x   |    80 |                 | Used by "bareos" package. |
| www-data | x   |    82 |                 | Created by "apache", "cacti", "caddy", "darkhttpd", "fcgiwrap", "forgejo", "freshrss", "gatling", "gitea", "gogs", "grocy-nginx", "h2o", "iipsrv", "lighttpd", "mini_httpd","nextcloud", "nginx", "openresty", "otrs", "sthttpd", "thttpd", "wt" packages. |
| usb      | x   |    85 |                 | Used by "usbmuxd" package. |
| vpopmail | x   |    89 |                 | **Safe to remove**. |
| users    | x   |   100 | games           | Created by "timed" package. |
| ntp      | x   |   123 |                 | |
| nofiles  | x   |   200 |                 | |
| smmsp    | x   |   209 | smmsp           | Created by "milter-greylist" package. |
| locate   | x   |   245 |                 | Created by "mlocate", "plocate" packages. |
| abuild   | x   |   300 |                 | **Safe to remove**. Created by "abuild" package. |
| utmp     | x   |   406 |                 | Used by /etc/init.d/bootmisc when creating utmp & wtmp files. Created by "utmps" package. |
| ping     | x   |   999 |                 | |
| nogroup  | x   | 65533 |                 | Used by "akms", "rezolus" packages. |
| nobody   | x   | 65534 |                 | |


???

- ossec-hids
- ossec-hids-server
- ossec-hids-local
