#!/bin/bash
FILENAME=`date +%Y%m%d`
cd /usr/local/u-mail/log
tar zcvf /home/backup/$FILENAME.tgz app/
