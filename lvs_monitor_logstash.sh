#!/bin/bash
#lvs结合ssh免密做监控，移除故障节点脚本
. /etc/profile
set -u
set -e

#定义时间格式
cur_time(){
        date "+%Y/%m/%d %H:%M:%S"
}

#节点恢复 lvs恢复对节点的转发规则
add_node(){
        ipvsadm -a -t $vip:$port -r $ip:$port -g #增加tcp转发规则
        ipvsadm -a -u $vip:$port -r $ip:$port -g #增加udp转发规则
        echo "$(cur_time) $ip:$port status success add node:ipvsadm -d -t $vip:$port -r $ip:$port " >> $file.log #写日志
        echo "$(cur_time) $ip:$port status success add node:ipvsadm -d -u $vip:$port -r $ip:$port " >> $file.log #写日志
        sed -i "/^$ip:$port/d" $file.node #移除恢复节点
}

#节点故障 lvs删除节点转发规则
delete_node(){
        ipvsadm -d -t $vip:$port -r $ip:$port #增加tcp转发规则
        ipvsadm -d -u $vip:$port -r $ip:$port #增加udp转发规则
        echo "$(cur_time) $ip:$port status error delete node:ipvsadm -d -t $vip:$port -r $ip:$port " >> $file.log #写日志
        echo "$(cur_time) $ip:$port status error delete node:ipvsadm -d -u $vip:$port -r $ip:$port " >> $file.log #写日志
        echo "$ip:$port" >> $file.node #记录故障节点 用于add恢复
}

vip="192.168.29.4" #lvs的虚IP
file=$(echo "$0"|awk -F"." '{print$1}') #日志文件名
ip_info=$(ipvsadm -ln|grep -v $vip|awk  'NR>3{print$2}'|sort|uniq) #获取现有ipvs表的转发规则
for ip_port in $ip_info; do
        ip=$(echo $ip_port|awk -F: '{print$1}') #切割获取IP
        port=$(echo $ip_port|awk -F: '{print$2}') #切割获取端口

        for ((i=0;i<6;i++));do
        	#ping这个IP如果不通说明节点已经挂了，直接就删除转发规则
                ping -W 2 -c 1 $ip &>/dev/null #直接ping这个IP
                if [ $? == 0 ];then
                        echo "$(cur_time) $i ping $ip status success" >> $file.log
                        break
                elif [ $i == 5 ];then
                        delete_node #5次失败说明节点已经异常，可以移除转发
                else
                        echo "$(cur_time) $i ping $ip status error" >> $file.log
                        sleep 1
                fi
        done
        #判断节点是否有在监听lvs上的转发端口，没有监听说明程序已经挂了，可以有多个端口
        #这边要事先做好ssh的免密，就是用ssh执行远程命令，后端Real Server不能禁止lvs禁止访问22端口
        if [ $(ssh root@$ip "ss -ant|grep "$port"|grep "LISTEN"|wc -l") -ne 1 ] ; then
                delete_node
        fi
done

#检查$file.node存的故障检点是否已经恢复
for ip_port in $(cat $file.node) ; do
        ip=$(echo $ip_port|awk -F: '{print$1}')
        port=$(echo $ip_port|awk -F: '{print$2}')

        ping -W 2 -c 1 $ip &>/dev/null

        if [ $? != 0 ];then
                continue
        fi
        #检查是否已经恢复对端口的监听
        if [ $(ssh root@$ip "ss -ant|grep "$port"|grep "LISTEN"|wc -l") -eq 1 ];then
                add_node #恢复lvs转发
        fi
done
