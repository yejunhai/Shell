#!/bin/bash
#使用crontab 调用每3分钟一次，超过6分钟可以判断为SYN攻击

#抓出处于SYN_RECV状态的IP地址 记录日志用于分析
netstat -antp|grep "SYN_RECV"|awk -F '[ :]' '{print$27}'|sort|uniq >> $0_ip.log
#分析日志找到大于2次被扫描到的IP地址，加入防火墙
for ip in `cat $0_ip.log|sort|uniq -c|awk '{if($1>2) print$2}'`
do
	rule=`grep "$ip" /etc/sysconfig/iptables|wc -l`
	#判断规则是否存在
	if [ "$rule" -ne 0 ];then
		echo "Firewall rule already exists"
	else
		#添加到防火墙 
		iptables -A INPUT -s $ip -j DROP
		#日志移除IP地址
		sed -i "s|\<$ip\>||" $0_ip.log
		#记录添加日志
		echo "$(date "+%Y-%m-%d %H:%M:%S") $ip Add to firewall" >> $0.log
	fi
done
#centos7中没有service iptables save指令来保存防火墙规则
iptables-save > /etc/sysconfig/iptables