# Validating utmp/wtmp functionality in Alpine Edge

State of UTMP/WTMP support in various Alpine binaries:

| Program         | Package             | Works? | Notes                         |
|:---------------:|:-------------------:|:------:|:-----------------------------:|
| ac              | acct                | Yes    | Reads wtmp file |
| agetty          | agetty              | Yes    | |
| dbclient        | dropbear-dbclient   | ?      | |
| dump-utmp       | acct                | Yes    | Reads utmp and wtmp files |
| getty           | busybox             | No*    | I am working on patch |
| halt            | busybox             | ?      | Called by /etc/init.d/bootmisc to write "shutdown" utmp entry |
| init            | busybox             | Yes    | Limited use of utmp, only relates to processes it kills |
| last            | acct                | n/a    | No longer built |
| last            | busybox             | Yes    | **I am seeing double entries for some users** |
| last            | util-linux-login    | Yes    | Reads wtmp file |
| lastb           | util-linux-login    | Yes    | Reads btmp file |
| login           | busybox             | No*    | I am working on patch |
| login           | shadow-login        | ?      | |
| login           | util-linux-login    | ?      | |
| logname         | coreutils           | Yes    | |
| logoutd         | shadow-login        | ?      | |
| lslogins        | util-linux-login    | ???    | |
| mingetty        | mingetty            | ?      | |
| n/a             | libutempter         | ?      | Used by other apps |
| openrc-init     | openrc              | n/a    | Not used by Alpine. MR to remove !29869 |
| openrc-shutdown | openrc              | n/a    | Not used by Alpine, etc/init.d/bootmisc uses "halt -w" instead. MR to remove !29869 |
| pinky           | coreutils           | Yes    | |
| runlevel        | busybox             | n/a    | Not built for Alpine |
| runuser         | runuser             | ?      | writes to btmp only |
| screen          | screen              | ?      | Via libutempter |
| sshd            | openssh-server      | ?      | |
| sshd.krb5       | openssh-server-krb5 | ?      | |
| sshd.pam        | openssh-server-pam  | Yes    | |
| su              | busybox             | Yes    | Writes syslog entries of su from/to users |
| su              | coreutils           | n/a    | Not built for Alpine |
| su              | shadow-login        | ?      | Is deprecated by Upstream |
| su              | util-linux-login    | ?      | Writes to btmp only |
| telnetd         | busybox             | n/a    | Not built for Alpine |
| tinysshd        | tinyssh             | No     | Not compiled against utmps |
| tmux            | tmux                | ?      | Via libutempter |
| uptime          | busybox             | No*    | Obtains number of logged in users from UTMP. I am working on patch |
| uptime          | coreutils           | n/a    | Not built for Alpine |
| uptime          | procps              | No*    | Not yet compiled with utmps - I have patch|
| users           | busybox             | n/a    | Not built for Alpine |
| users           | coreutils           | Yes    | |
| utmpdump        | util-linux-misc     | Yes    | |
| utmpset         | runit               | ?      | |
| uu_pinky        | uutils-coreutils    | No     | Not built for Alpine |
| w               | busybox             | n/a    | Not built for Alpine |
| w               | procps              | No*    | Not yet compiled with utmps - I have patch |
| wall            | busybox             | n/a    | Not built for Alpine |
| wall            | util-linux-misc     | Yes    | Uses UTMP to get terminals of logged in users |
| whattime?       | procps              | ?      | |
| who             | busybox             | No*    | Uses UTMP to get terminals of logged in users. I am working on patch |
| who             | coreutils           | Yes    | |
| who             | shadow-login        | ?      | |
| who             | util-linux          | n/a    | Not built for Alpine |
| who             | uutils-coreutils    | n/a    | Not built for Alpine |
| write           | util-linux          | n/a    | Not built for Alpine |
| ?               | sudo                | ?      | |

NOTES:

- /etc/init.d/bootmisc from openrc package creates utmp/wtmp files during boot, /etc/init.d/utmp-init will delete/replace these files later in boot but the bootmisc functionality **needs to be kept** as otherwise on systems without utmps installed/enabled some utmp-enabled programs may give errors when they try to read or write utmp/wtmp files, such as:


utmp/wtmp record types:

| Id | Type          | Written by                     | Read by                                |
|:--:|:-------------:|:------------------------------:|:--------------------------------------:|
| 0  | EMPTY         |                                |                                        |
| 1  | RUN_LVL       | halt                           |                                        |
| 2  | BOOT_TIME     |                                | uptime                                 |
| 3  | NEW_TIME      |                                | uptime                                 |
| 4  | OLD_TIME      |                                | uptime                                 |
| 5  | INIT_PROCESS  | halt                           | agetty, halt, mingetty                 |
| 6  | LOGIN_PROCESS | agetty, getty, halt, mingetty  | halt                                   |
| 7  | USER_PROCESS  | halt, libutempter, login       | agetty, halt, mingetty, uptime, wall, who, write |
| 8  | DEAD_PROCESS  | halt, init, libutempter, login | agetty, halt, uptime                   |
