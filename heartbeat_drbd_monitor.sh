#!/bin/bash
#author:gxm
#date:2018-05-15
#version:1.1

HOSTNAME1="drbd1.db.com"
HOSTNAME2="drbd2.db.com"
CURRDATE=$(date "+%Y-%m-%d %H:%M:%S")
DRBD_HALOG=/var/log/drbd_ha.log
CURRENTHOST_HEARTBEAT_STATUS=/tmp/currenthost_heartbeat_status.txt
OTHERHOST_HEARTBEAT_STATUS=/tmp/otherhost_heartbeat_status.txt
CURRENTHOST_DRBD_DETAILED=/tmp/currenthost_drbd_detailed.txt
OTHERHOST_DRBD_DETAILED=/tmp/otherhost_drbd_detailed.txt


#退出脚本
function force_exit()
{
   echo "$CURRDATE: 脚本意外退出!" | tee -a $DRBD_HALOG
   echo
   exit 1;
}


# 输出日志提示
function output_notify()
{
   echo $CURRDATE：$1 | tee -a $DRBD_HALOG
}


# 输出错误提示
function output_error()
{
   echo "$CURRDATE：[ERROR] >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>" | tee -a $DRBD_HALOG
   echo "$CURRDATE：[ERROR] "$1 | tee -a $DRBD_HALOG
   echo "$CURRDATE：[ERROR] <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<" | tee -a $DRBD_HALOG
}


#检测root用户
function check_user_root()
{
   if [ `id -u` -eq 0 ]
    then
     output_notify "当前是root账号，正在执行脚本"
    else
     output_error "当前是非root账号，退出脚本"
     force_exit
   fi
}
check_user_root


#检测操作系统版本
function check_os()
{
if uname -a | grep 'el5' >/dev/null 2>&1
 then
    SYS_RELEASE="el5"
 elif uname -a | grep 'el7' >/dev/null 2>&1
  then
    SYS_RELEASE="el7"
 else
    SYS_RELEASE="el6"
fi
}


#安装配置mailx客户端工具
function mailx()
{
yum -y install mailx
cat >> /etc/mail.rc  << EOF
set from="umailtest@163.com"
set smtp=smtp.163.com
set smtp-auth-user=umailtest@163.com
set smtp-auth-password=123456
set smtp-auth=login
EOF
}


#检测mailx是否安装，如果没安装安装下
function check_mailx_program()
{
  check_os
  if [ $SYS_RELEASE = el6 ]
   then
    if [ ! -e /bin/mailx ]
     then
      echo "现在安装mailx工具!"
      mailx
    fi
  elif [ $SYS_RELEASE = el7 ] 
   then
    if [ ! -e /usr/bin/mailx ]
     then
      echo "现在安装mailx工具!"
      mailx
    fi
  else
   echo "此脚本只适用于centos6和7版本"
  fi
}
check_mailx_program


#发送邮件函数的帮助
function sendmailhelp()
{
   echo "eg: $0 [Subject] [address] [content_file] [file]"
   echo ""
   exit 1
}


#具体发送邮件函数
#$1为邮件标题，$2为收件人邮箱地址，$3为邮件内容，$4为附件（不是必须）
function sendmail()
{
if [ ! -n "$1" ]
 then
    sendmailhelp
fi

cDate=`date +%Y%m%d`
if [ ! -n "$2" ]
 then
    sendmailhelp
 else
    mail_to=$2
    echo "      Send Mail to ${mail_to}"
fi

if [ ! -n "$4" ]
 then
    mail -s $1 ${mail_to}<$3
 else
    mail -s $1 -a $4 ${mail_to}<$3
fi
}


#检查操作系统版本
function check_os()
{
if uname -a | grep 'el5' >/dev/null 2>&1
 then
    SYS_RELEASE="el5"
 elif uname -a | grep 'el7' >/dev/null 2>&1
  then
    SYS_RELEASE="el7"
 else
    SYS_RELEASE="el6"
fi
}


#获取当前主机名并给另外一台主机赋予相关远程信息
CURRENT_HOSTNAME=`hostname`
if [ $CURRENT_HOSTNAME = "$HOSTNAME1" ]
then
 output_notify "当前服务器主机名为$CURRENT_HOSTNAME"
 OTHER_HOST="192.168.40.52"
 OTHER_PROT="22"
 OTHER_USER="root"
 OTHER_PASSWD="123456"
elif [ $CURRENT_HOSTNAME = "$HOSTNAME2" ]
 then
 output_notify "当前服务器主机名为$CURRENT_HOSTNAME"
 OTHER_HOST="192.168.40.54"
 OTHER_PROT="22"
 OTHER_USER="root"
 OTHER_PASSWD="123456"
else
 echo "您主机名不符合要求"
fi


#远程到另外一台主机的函数
function ssh_otherhost()
{
if [ ! -e /usr/bin/expect ]
  then
   echo "现在安装expect工具!"
   yum -y install expect
fi
/usr/bin/expect<<EOF
spawn ssh -t -p "$OTHER_PROT" $OTHER_USER@$OTHER_HOST "$1" 
expect {
"yes/no" { send "yes\r"}
"*password:" { send "$OTHER_PASSWD\r" }
}
expect eof
EOF
}


#将查询服务状态导出到txt文件中
function outtxt()
{
  $1 > $2
  ssh_otherhost "$1" > $3
}


check_os
if [ $SYS_RELEASE = el6 ]
 then
  outtxt "/etc/init.d/heartbeat status" "$CURRENTHOST_HEARTBEAT_STATUS" "$OTHERHOST_HEARTBEAT_STATUS"
  outtxt "cat /proc/drbd" "$CURRENTHOST_DRBD_DETAILED" "$OTHERHOST_DRBD_DETAILED"
 elif [ $SYS_RELEASE = el7 ]
 then
  outtxt "systemctl status heartbeat" "$CURRENTHOST_HEARTBEAT_STATUS" "$OTHERHOST_HEARTBEAT_STATUS"
  outtxt "cat /proc/drbd" "$CURRENTHOST_DRBD_DETAILED" "$OTHERHOST_DRBD_DETAILED"
 else
  echo "此脚本只支持centos6和7"
fi


#使用返回码返回当前服务器heartbeat服务状态
function currenthost_heartbeat()
{
cat $CURRENTHOST_HEARTBEAT_STATUS | egrep "Active.*active.*running" >/dev/null 2>&1
reslut=$?
if [ $reslut -eq 0 ]
 then
  output_notify "当前服务器heartbeat服务运行正常"
  return 0
 else
  output_error "当前服务器heartbeat服务异常，请检查"
  return 1
fi
}  


#使用返回码返回当前另外一台服务器heartbeat服务状态
function otherhost_heartbeat()
{
cat $OTHERHOST_HEARTBEAT_STATUS | egrep "Active.*active.*running" >/dev/null 2>&1
reslut=$?
if [ $reslut -eq 0 ]
 then
  output_notify "另一台服务器heartbeat服务运行正常"
  return 0
 else
  output_error "另一台服务器heartbeat服务异常，请检查"
  return 1
fi
}  


#drbd的主从状态函数
function drbd_status()
{
currenthost_drbd=`cat $CURRENTHOST_DRBD_DETAILED | grep "ro:"|awk -F" " '{print $3}'`
otherhost_drbd=`cat $OTHERHOST_DRBD_DETAILED | grep "ro:"|awk -F" " '{print $3}'`
if ([[ $currenthost_drbd = "ro:Secondary/Primary" ]] && [[ $otherhost_drbd = "ro:Primary/Secondary" ]]) || ([[ $currenthost_drbd = "ro:Primary/Secondary" ]] && [[ $otherhost_drbd = "ro:Secondary/Primary" ]])
 then
  output_notify "drbd主从状态正常"
  return 0
 else
  output_error "drbd主从状态异常，请详细检查或参考$DRBD_HALOG日志"
  return 1
fi
}


#drbd的同步状态函数
function drbd_status_update()
{
currenthost_drbd_update=`cat $CURRENTHOST_DRBD_DETAILED | grep "ro:"|awk -F" " '{print $4}'`
otherhost_drbd_update=`cat $OTHERHOST_DRBD_DETAILED | grep "ro:"|awk -F" " '{print $4}'`
if [[ $currenthost_drbd_update = "ds:UpToDate/UpToDate" ]] && [[ $otherhost_drbd_update = "ds:UpToDate/UpToDate" ]]
 then
  output_notify "drbd同步状态正常"
  return 0
 else
  output_error "drbd同步状态异常，请详细检查或参考$DRBD_HALOG日志"
  return 1
fi
}


#判断两台服务器heartbeat运行情况
currenthost_heartbeat
currenthost_heartbeat_code=$?
otherhost_heartbeat
otherhost_heartbeat_code=$?
if [ $currenthost_heartbeat_code -eq 0 ] && [ $otherhost_heartbeat_code -eq 0 ] 
 then
  output_notify "恭喜，两台服务器heartbeat服务均运行正常"
 else
  output_error "heartbeat服务异常，请详细检查或参考$DRBD_HALOG日志"
  sendmail "heartbeat服务异常，详细见邮件正文" gxm@comingchina.com $DRBD_HALOG
fi


#判断两台服务器drbd运行情况
drbd_status
drbd_status_code=$?
drbd_status_update
drbd_status_update_code=$?
if [ $drbd_status_code -eq 0 ] && [ $drbd_status_update_code -eq 0 ]
 then
  output_notify "恭喜，两台服务器drbd运行正常"
 else
  output_error "drbd运行不正常，请详细检查或参考$DRBD_HALOG日志"
  sendmail "drbd服务异常，详细见邮件正文" gxm@comingchina.com $DRBD_HALOG
fi
