#! /bin/bash
#定义路径变量
MAILDOMAIN=domain.com
WINDIR=/windows/Users/$MAILDOMAIN
LINDIR=/usr/local/u-mail/data/mailbox/$MAILDOMAIN/0
WINCAOGAO="Drafts.IMAP"
WINLAJI="Deleted Items.IMAP"
WINFA="Sent Items.IMAP"
WINZI="Inbox.IMAP"
DATADIR=/usr/local/u-mail/data/mailbox

#循环读取帐号
ls -lh $WINDIR | awk -F " " '{ print $NF }' | sed 1d | while read LINE
do
 umailuser=$(echo $LINE |awk  '{print $1}')
 if [ ! -d "$LINDIR/$umailuser" ]; then
  mkdir -p $LINDIR/$umailuser/cur
  mkdir -p $LINDIR/$umailuser/.Drafts/cur
  mkdir -p $LINDIR/$umailuser/.Trash/cur
  mkdir -p $LINDIR/$umailuser/.Sent/cur
 fi
 echo -e
 echo -e
 echo "#####################################开始迁移$umailuser用户数据##############################################"
 echo "复制收件箱"
 rsync -avzrtopgL  --progress $WINDIR/$umailuser/*.msg $LINDIR/$umailuser/cur/
 echo -e
 echo "复制草稿箱"
 rsync -avzrtopgL  --progress $WINDIR/$umailuser/"${WINCAOGAO}"/*.msg $LINDIR/$umailuser/.Drafts/cur/
 echo -e
 echo "复制垃圾箱"
 rsync -avzrtopgL  --progress $WINDIR/$umailuser/"${WINLAJI}"/*.msg $LINDIR/$umailuser/.Trash/cur/
 echo -e
 echo "复制发件箱"
 rsync -avzrtopgL  --progress $WINDIR/$umailuser/"${WINFA}"/*.msg $LINDIR/$umailuser/.Sent/cur/

   echo -e
   echo -e
   echo "复制用户自建文件夹数据"
   ls -l $WINDIR/$umailuser |grep "IMAP" |grep -v "Sent Items" | grep -v "Drafts" | grep -v "Deleted Items" | grep -v "Inbox" |awk '{printf ".INBOX.%s\n", $9}' | sed s/\.IMAP//g | while read DIY
   do
   mkdir -p $LINDIR/$umailuser/$DIY
   WINDIY=$(echo $DIY |sed 's/.INBOX.//g' |sed 's/$/&.IMAP/g')
   rsync -avzrtopgL  --progress $WINDIR/$umailuser/$WINDIY/*.msg $LINDIR/$umailuser/$DIY/cur/
   done
   
   echo -e
   echo -e
   echo "复制子文件夹数据"
   ls -l $WINDIR/$umailuser/"${WINZI}" |grep "IMAP" |grep -v "Sent Items" | grep -v "Drafts" | grep -v "Deleted Items" | grep -v "Inbox" |awk '{printf ".INBOX.%s\n", $9}' | sed s/\.IMAP//g | while read ZIY
   do
   mkdir -p $LINDIR/$umailuser/$ZIY
   WINZIY=$(echo $ZIY |sed 's/.INBOX.//g' |sed 's/$/&.IMAP/g')
   rsync -avzrtopgL  --progress $WINDIR/$umailuser/"${WINZI}"/$WINZIY/*.msg $LINDIR/$umailuser/$ZIY/cur/
   done
   echo "####################################迁移完成$umailuser用户数据#############################################"
 done

echo -e
echo -e
echo "******迁移完成******"
echo "设置权限完成"
chown -hR umail.umail $DATADIR
chmod -R 755 $DATADIR


