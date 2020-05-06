#!/bin/bash

#设置安装目录
path=/opt
#判断filebeat是否运行，运行退出安装
if [ `ps -ef|grep "filebeat.yml"|wc -l` -gt 1 ];then
	echo "filebeat process already exists"
	exit 1
fi

#创建目录，解压文件，指定filebeat.yml配置文件
mkdir -p $path
tar -zxf filebeat-7.2.0-linux-x86_64.tar.gz -C $path
file=$path/filebeat-7.2.0-linux-x86_64/filebeat.yml

#修改配置文件filebeat.inputs:配置，删除不需要的配置，添加oracle alert日志路径
sed -i "21,28d" $file
cd /u01/app/oracle/diag/rdbms
for dir in `ls`
do
	if [ ! -d $dir ];then
		continue
	fi
	cd $dir
	for dir1 in `ls`
	do
		if [ ! -d $dir1 ];then
			continue
		fi
		cd $dir1/trace
		sed -i "/filebeat.inputs:/a\      - `pwd`/*.log" $file
		sed -i "/filebeat.inputs:/a\    paths:" $file
		sed -i "/filebeat.inputs:/a\    tags: ["$dir1"]" $file
		sed -i "/filebeat.inputs:/a\    enabled: true" $file
		sed -i "/filebeat.inputs:/a\  - type: log" $file
		cd /u01/app/oracle/diag/rdbms/$dir 
	done
	cd /u01/app/oracle/diag/rdbms
done

#设置传送日志的地址
sed -i "s/output.elasticsearch:/output.logstash:/" $file
sed -i "s/localhost:9200/192.168.29.4:15531/" $file
#运行filebeat
cd $path/filebeat-7.2.0-linux-x86_64
nohup ./filebeat -e -c $file  > /dev/null  &
sleep 5
#检查是否运行成功
if [ `ps -ef|grep "filebeat.yml"|wc -l` -gt 1 ];then
        echo "filebeat process running"
        exit 0
else
	echo "filebeat installation failed"
	exit 1
fi