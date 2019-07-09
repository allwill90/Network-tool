 #!/usr/bin/env bash

#=================================================
#	System Required: CentOS7
#	Description: install bbrPlus
#	Version: 1.0.0
#	Author: leone
#=================================================

kernel_version="4.14.129-bbrplus"

# check system 
if [[ ! -f /etc/redhat-release ]]; then
	echo -e "only support CentOS..."
	exit 0
fi

if [[ "$(uname -r)" == "${kernel_version}" ]]; then
	echo -e "The kernel is installed and there is no need to repeat execution."
	exit 0
fi

# uninstall bbr
echo -e "uninstall bbr..."
sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
if [[ -e /appex/bin/serverSpeeder.sh ]]; then
	wget https://github.com/janlle/ssr/tree/master/install-ssr/appex.sh && chmod +x appex.sh && bash appex.sh uninstall
	rm -f appex.sh
fi

# install bbrplus
echo -e "downloading bbr plus kernel..."
wget https://github.com/janlle/ssr/tree/master/CentOS_7.x/x86_64/kernel-${kernel_version}.rpm
echo -e "install kernel..."
yum install -y kernel-${kernel_version}.rpm

# 检查内核是否安装成功
list="$(awk -F\' '$1=="menuentry " {print i++ " : " $2}' /etc/grub2.cfg)"
target="CentOS Linux (${kernel_version})"
result=$(echo $list | grep "${target}")
if [[ "$result" = "" ]]; then
	echo -e "kernel install failed"
	exit 1
fi

# 启用 bbrplus 内核
echo -e "change kernel..."
grub2-set-default 'CentOS Linux (${kernel_version}) 7 (Core)'
echo -e "start bbrplus mode..."
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbrplus" >> /etc/sysctl.conf
rm -f kernel-${kernel_version}.rpm

read -p "bbrplus install successful reboot now? [y/n] :" yn
[ -z "${yn}" ] && yn="y"
if [[ $yn == [Yy] ]]; then
	echo -e "reboot..."
	reboot
fi
