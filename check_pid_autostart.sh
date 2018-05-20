#!/bin/sh
if [ -e /usr/local/u-mail/app/run/imapmail.pid ]
then
echo "running"
else
echo "not"
/usr/local/u-mail/app/exec/imapmail --host 121.9.226.91 /usr/local/u-mail/user
fi
