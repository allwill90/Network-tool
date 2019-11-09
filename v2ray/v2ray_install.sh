#!/usr/bin/env bash

# If not specify, default meaning of return value:
# 0: Success
# 1: System error
# 2: Application error
# 3: Network error

#--------- Colors Code ---------
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;36m"

#--------- script constant ---------
VDIS="64"
OS_TYPE="unknown"
SOURCE_FILE="/tmp/v2ray/v2ray-linux-${VDIS}.zip"
LOG_DIR="/var/log/v2ray"
COMMAND="/usr/local/bin/v2ray"
V2RAY_PORT=$(shuf -i10000-65535 -n1)
UUID=$(cat /proc/sys/kernel/random/uuid)


print() {
    echo -e "$1${@:2}\033[0m"
}

# check system

sys_arch(){
    ARCH=$(uname -m)
    if [[ "$ARCH" == "i686" ]] || [[ "$ARCH" == "i386" ]]; then
        VDIS="32"
    elif [[ "$ARCH" == *"armv7"* ]] || [[ "$ARCH" == "armv6l" ]]; then
        VDIS="arm"
    elif [[ "$ARCH" == *"armv8"* ]] || [[ "$ARCH" == "aarch64" ]]; then
        VDIS="arm64"
    elif [[ "$ARCH" == *"mips64le"* ]]; then
        VDIS="mips64le"
    elif [[ "$ARCH" == *"mips64"* ]]; then
        VDIS="mips64"
    elif [[ "$ARCH" == *"mipsle"* ]]; then
        VDIS="mipsle"
    elif [[ "$ARCH" == *"mips"* ]]; then
        VDIS="mips"
    elif [[ "$ARCH" == *"s390x"* ]]; then
        VDIS="s390x"
    elif [[ "$ARCH" == "ppc64le" ]]; then
        VDIS="ppc64le"
    elif [[ "$ARCH" == "ppc64" ]]; then
        VDIS="ppc64"
    fi
    return 0
}

# check machine type

# CentOS yum dnf
if [[ -f "/etc/redhat-release" ]];then
    OS_TYPE="CentOS"
# Debian apt
elif [[ -f "/etc/debian-release" ]];then
    OS_TYPE="Debian"
# Ubuntu apt
elif [[ -f "/etc/lsb_release" ]];then
    OS_TYPE="Ubuntu"
# Fedora yum dnf
elif [[ -f "/et/fedora-release" ]];then
    OS_TYPE="Fedora"
fi

if [[ ${OS_TYPE} == "unknown" ]];then
    print ${RED} "This script not support your machine"
    exit 0
fi

# check net work
IP=$(curl -s https://ifconfig.me/)
[[ -z ${IP} ]] && ip=$(curl -s https://api.ip.sb/ip)
[[ -z ${IP} ]] && ip=$(curl -s https://api.ipify.org)
[[ -z ${IP} ]] && ip=$(curl -s https://ip.seeip.org)
[[ -z ${IP} ]] && ip=$(curl -s https://ifconfig.co/ip)
[[ -z ${IP} ]] && ip=$(curl -s http://icanhazip.com)
if [[ ! ${IP} =~ ^([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])$ ]]
then
    print ${RED} "Your machine can't connect to the Internet"
    exit 3
fi

# install require package
install_package() {
    for i in $@;do
        echo ${i}
        if [[ ! -x "$(command -v ${i})" ]];then
            if [[ ${OS_TYPE} -eq "CentOS" || ${OS_TYPE} -eq "Fedora" ]];then
                yum install -y ${i}
            elif [[ ${OS_TYPE} -eq "Ubuntu" || ${OS_TYPE} -eq "Debian" ]];then
                apt install -y ${i}
            fi
        fi
    done
}

install_package curl wget git unzip jq


# async date
async_date() {
    yum install -y chrony && systemctl start chronyd && systemctl enable chronyd
#    cat >/etc/chrony.conf <<EOF
#        server 0.centos.pool.ntp.org iburst
#        server 1.centos.pool.ntp.org iburst
#        server 2.centos.pool.ntp.org iburst
#        server 3.centos.pool.ntp.org iburst
#    EOF
}


download_v2ray() {
    rm -rf /tmp/v2ray && mkdir -p /tmp/v2ray
    LATEST_VERSION=$(curl -s https://api.github.com/repos/v2ray/v2ray-core/releases/latest | jq .tag_name)
    if [[ ! ${LATEST_VERSION} ]]; then
        print ${RED} "Got v2ray version failed please check your network and retry" && exit 3
    fi
    V2RAY_DOWNLOAD_LINK="https://github.com/v2ray/v2ray-core/releases/download/${LATEST_VERSION//\"/}/v2ray-linux-${VDIS}.zip"
    if ! wget --no-check-certificate -q --show-progress ${SOURCE_FILE} -O ${V2RAY_DOWNLOAD_LINK}; then
		print ${RED} "Download failed please check your network and retry." && exit 3
	fi
}

install_v2ray_service() {
    cp -f /tmp/v2ray/systemd/v2ray.service /etc/systemd/system/
    chmod +x /etc/systemd/system/v2ray.service
}


install_v2ray() {
    if [[ -f /usr/bin/v2ray/v2ray || -f /etc/v2ray/config.json || -f /etc/systemd/system/v2ray.service ]]; then
		echo "You have installed v2ray. Please uninstall it if you want reinstall it."
		exit 1
	fi
    download_v2ray
    rm -rf /usr/bin/v2ray/* /etc/v2ray/config.json
    mkdir -p /usr/bin/v2ray/ /etc/v2ray/
    unzip /tmp/v2ray/v2ray-linux-${VDIS}.zip -d /tmp/v2ray/
    cp -f /tmp/v2ray/v2ray /tmp/v2ray/v2ctl /usr/bin/v2ray/
    cp -f /tmp/v2ray/geoip.dat /tmp/v2ray/geosite.dat /usr/bin/v2ray/
    cp -f /tmp/v2ray/vpoint_vmess_freedom.json /etc/v2ray/config.json

	# Config port
	while :; do
        print ${BLUE} "请输入 V2Ray 端口 [10000-65535]"
        read -p "$(print ${BLUE} "(默认端口: ${V2RAY_PORT}):")" v2ray_port
        [[ -z "$v2ray_port" ]] && break
        if [[ `echo "${V2RAY_PORT}*1" | bc` -eq 0 ]] || ((v2ray_port<10000)) || ((v2ray_port>65535));then
            print ${RED} "Please enter 1000 to 65535!"
        else
            V2RAY_PORT=${v2ray_port}
            break
        fi
    done

    # Config
    sed -i "s/10086/${V2RAY_PORT}/g" "/etc/v2ray/config.json"
    sed -i "s/23ad6b10-8d1a-40f7-8ad0-e3e35cd38297/${UUID}/g" "/etc/v2ray/config.json"

    # Install service and start
    install_v2ray_service
    systemctl enable v2ray
    systemctl start v2ray

	# Print install config info
    print ${GREEN} "V2Ray端口: ${V2RAY_PORT}"
    echo
    print ${GREEN} "Ip: ${IP}"
    echo
    print ${GREEN} "Install v2ary successful"

}


uninstall_v2ray() {

    if [[ -f "/etc/systemd/system/v2ray.service" ]];then
        systemctl disable v2ray && systemctl stop v2ray && rm -f /etc/systemd/system/v2ray.service
    fi

    if [[ -d /usr/bin/v2ray ]]; then
		rm -rf /usr/bin/v2ray
	fi

    if [[ -d /etc/v2ray ]];then
        rm -rf /etc/v2ray
    fi

    if [[ -d "/var/log/v2ray" ]];then
        rm -rf /var/log/v2ray
    fi

    print ${GREEN} "V2Ray uninstall successful!"

    exit 0

}


reinstall_v2ray() {
    uninstall_v2ray
    install_v2ray
    print ${GREEN} "Reinstall successful!"
}



while :; do
	echo
	print ${GREEN} "1.Install V2Ray"
	echo
	print ${GREEN} "2.Uninstall V2Ray"
	echo
	print ${GREEN} "3.Reinstall V2Ray"
	echo
	print ${GREEN} "4.Exit"
	echo
	read -p "$(print ${BLUE} "请选择 [1-4]:")" option
	case ${option} in
	1)
		install_v2ray
		break
		;;
	2)
		uninstall_v2ray
		break
		;;
	3)
	    reinstall_v2ray
	    break
	    ;;
	4)
	    exit 0
	    break
	    ;;
	*)
		print ${RED} "Please enter 1 to 4!"
		;;
	esac
done


# config protocol
#	while :; do
#	    DEFAULT_PROTOCOL=1
#		echo -e "请选择"${YELLOW}"V2Ray"${PLAIN}"传输协议 [${MAGENTA}1-${#PROTOCOL[@]}${PLAIN}]"
#		echo
#		for key in ${!PROTOCOL[*]};do
#		    echo -e "${key}.${PROTOCOL[${key}]}"
#		done
#		echo
#		read -p "$(echo -e "(默认协议: ${CYAN}TCP${PLAIN})"):" v2ray_protocol
#		[[ -z "$v2ray_protocol" ]] && v2ray_protocol=1
#		case ${v2ray_protocol} in
#		[1-9] | [1-2][0-9] | 3[0-2])
#		    DEFAULT_PROTOCOL = ${v2ray_protocol}
#			echo
#			echo -e "${YELLOW}V2Ray 传输协议: ${PROTOCOL[${v2ray_protocol}]}${PLAIN}"
#			break
#			;;
#		*)
#			error
#			;;
#		esac
#	done