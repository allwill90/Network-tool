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
ISA="64"
OS_TYPE="unknown"
OS_FULL_NAME=""
PROTOCOL=""
PASSWORD=$(openssl rand -base64 8)
SOURCE_FILE="/tmp/v2ray/v2ray-linux-${ISA}.zip"
LOG_DIR="/var/log/v2ray"
COMMAND="/usr/local/bin/v2ray"
PORT=$(shuf -i10000-65535 -n1)
UUID=$(cat /proc/sys/kernel/random/uuid)
SYSTEMCTL_CMD=$(command -v systemctl 2>/dev/null)
SERVICE_CMD=$(command -v service 2>/dev/null)


print() {
    echo -e "$1${@:2}\033[0m"
}

# Check run with root .
[[ $(id -u) != 0 ]] && print ${RED} "This script only supports run with the root." && exit 1


# Check system ISA .
sys_arch(){
    ARCH=$(uname -m)
    if [[ "$ARCH" == "i686" ]] || [[ "$ARCH" == "i386" ]]; then
        ISA="32"
    elif [[ "$ARCH" == *"armv7"* ]] || [[ "$ARCH" == "armv6l" ]]; then
        ISA="arm"
    elif [[ "$ARCH" == *"armv8"* ]] || [[ "$ARCH" == "aarch64" ]]; then
        ISA="arm64"
    elif [[ "$ARCH" == *"mips64le"* ]]; then
        ISA="mips64le"
    elif [[ "$ARCH" == *"mips64"* ]]; then
        ISA="mips64"
    elif [[ "$ARCH" == *"mipsle"* ]]; then
        ISA="mipsle"
    elif [[ "$ARCH" == *"mips"* ]]; then
        ISA="mips"
    elif [[ "$ARCH" == *"s390x"* ]]; then
        ISA="s390x"
    elif [[ "$ARCH" == "ppc64le" ]]; then
        ISA="ppc64le"
    elif [[ "$ARCH" == "ppc64" ]]; then
        ISA="ppc64"
    fi
    return 0
}

# Check machine type .

# CentOS yum dnf
if [[ -f "/etc/redhat-release" ]];then
    OS_TYPE="CentOS" && OS_FULL_NAME=$(cat /etc/redhat-release)
# Debian apt
elif [[ -f "/etc/debian_version" ]];then
    OS_TYPE="Debian" && OS_FULL_NAME=$(cat /etc/debian_version)
# Ubuntu apt
elif [[ -f "/etc/lsb-release" ]];then
    OS_TYPE="Ubuntu" && OS_FULL_NAME=$(head -1 /etc/lsb-release)
# Fedora yum dnf
elif [[ -f "/etc/fedora-release" ]];then
    OS_TYPE="Fedora" && OS_FULL_NAME=$(/etc/fedora-release)
fi

if [[ ${OS_TYPE} == "unknown" ]];then
    print ${RED} "This script not support your machine"
    exit 0
fi


# Check network
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

# Print machine information .
system_info() {
    echo
    echo "##############################################"
    echo "# One click Install V2ray Server             #"
    echo "# Intro: https://github.com/v2ray/v2ray-core #"
    echo "# Author: Leone <exklin@leone.com>           #"
    echo "# Blog: http://exklin.xyz/                   #"
    echo "##############################################"
    echo
    echo
    print ${GREEN} "System type: ${OS_FULL_NAME}"
    echo
    print ${GREEN} "Kernel version: $(uname -r)"
    echo
    print ${GREEN} "ISA: ${OS_TYPE} $(uname -m)"
    echo
    print ${GREEN} "Ip: ${IP}"
    echo
}

system_info

# Install require packages.
install_package() {
    for i in $@;do
        if [[ ! -x "$(command -v ${i})" ]];then
            if [[ "${OS_TYPE}" == "CentOS" || "${OS_TYPE}" == "Fedora" ]];then
                yum install -y ${i}
            elif [[ "${OS_TYPE}" == "Ubuntu" || "${OS_TYPE}" == "Debian" ]];then
                apt install -y ${i}
            fi
        fi
    done
}

install_package curl wget git unzip jq


# Async date
async_date() {
    yum install -y chrony && systemctl start chronyd && systemctl enable chronyd
#    cat >/etc/chrony.conf <<EOF
#        server 0.centos.pool.ntp.org iburst
#        server 1.centos.pool.ntp.org iburst
#        server 2.centos.pool.ntp.org iburst
#        server 3.centos.pool.ntp.org iburst
#    EOF
}

config_port() {
    while :;do
        PORT=$(shuf -i10000-65535 -n1)
        echo
        print ${GREEN} "Please enter ${1} port 10000 to 65535"
        echo
        read -p "$(print ${BLUE} "(Default: ${PORT}): ")" port
        [[ -z "${port}" ]] && break
        if [[ `echo "${port}*1" | bc` -eq 0 && ((${port}<10000)) && ((${port}>65535)) ]];then
            PORT=${port}
            break
        fi
    done
}

config_password() {
    while :;do
        PASSWORD=$(openssl rand -base64 8)
        echo
        print ${GREEN} "Please enter ${1} password not less than 6 characters ."
        echo
        read -p "$(print ${BLUE} "(Default: ${PASSWORD}): ")" password
        [[ -z "${password}" ]] && break
        if (($(echo ${PASSWORD} | wc -c)>6 && $(echo ${PASSWORD} | wc -c)<37));then
            PASSWORD=${password}
            break
        fi
    done
}

config_protocol() {
    PROTOCOL=1
    while :;do
        for key in ${!1[*]};do
		    print ${GREEN} "$key.${1[$key]}"
		    echo
		done
        print ${GREEN} "Please enter ${1} protocol 1 to ${#1[@]}"
        echo
        read -p "$(print ${BLUE} "(Default: ${PROTOCOL}): ")" option
        if [[ ${option} -gt 0 ]] && ((${option}<=${#1[@]}));then
            print ${RED} ${option}
            break
        fi
    done
    echo
}


download_v2ray() {
    rm -rf /tmp/v2ray && mkdir -p /tmp/v2ray
    LATEST_VERSION=$(curl -s https://api.github.com/repos/v2ray/v2ray-core/releases/latest | jq .tag_name)
    if [[ ! ${LATEST_VERSION} ]]; then
        print ${RED} "Got v2ray version failed please check your network and retry" && exit 3
    fi
    V2RAY_DOWNLOAD_LINK="https://github.com/v2ray/v2ray-core/releases/download/${LATEST_VERSION//\"/}/v2ray-linux-${ISA}.zip"
    if ! wget --no-check-certificate -q --show-progress -O ${SOURCE_FILE} ${V2RAY_DOWNLOAD_LINK}; then
		print ${RED} "Download failed please check your network and retry." && exit 3
	fi
}

install_v2ray_service() {
    if [[ -n "${SYSTEMCTL_CMD}" ]];then
        cp -f /tmp/v2ray/systemd/v2ray.service /etc/systemd/system/
        chmod +x /etc/systemd/system/v2ray.service
        systemctl enable v2ray && systemctl start v2ray
        return
    elif [[ -n "${SERVICE_CMD}" ]] && [[ ! -f "/etc/init.d/v2ray" ]]; then
        cp -f /tmp/v2ray/systemv/v2ray /etc/init.d/v2ray
        chmod +x /etc/init.d/v2ray
        update-rc.d v2ray defaults
    fi
}


install_v2ray() {
    if [[ -f /usr/bin/v2ray/v2ray || -f /etc/v2ray/config.json || -f /etc/systemd/system/v2ray.service ]]; then
		echo "You have installed v2ray. Please uninstall it if you want reinstall it."
		exit 1
	fi
    download_v2ray
    rm -rf /usr/bin/v2ray/* /etc/v2ray/config.json
    mkdir -p /usr/bin/v2ray/ /etc/v2ray/ /var/log/v2ray
    unzip /tmp/v2ray/v2ray-linux-${ISA}.zip -d /tmp/v2ray/ > /dev/null 2>&1
    cp -f /tmp/v2ray/v2ray /tmp/v2ray/v2ctl /usr/bin/v2ray/
    cp -f /tmp/v2ray/geoip.dat /tmp/v2ray/geosite.dat /usr/bin/v2ray/
    cp -f /tmp/v2ray/vpoint_vmess_freedom.json /etc/v2ray/config.json

	# Config port
	config_port "v2ray vmess protocol"

    # Config
    sed -i "s/10086/${PORT}/g" "/etc/v2ray/config.json"
    sed -i "s/23ad6b10-8d1a-40f7-8ad0-e3e35cd38297/${UUID}/g" "/etc/v2ray/config.json"

    # Install service and start
    install_v2ray_service


	# Print install config info
	echo
    print ${GREEN} "V2Ray port: ${PORT}"
    echo
    print ${GREEN} "Ip: ${IP}"
    echo
	print ${GREEN} "UUID: ${UUID}"
    echo
	print ${GREEN} "ExtraID: $(jq .inbounds[0].settings.clients[0].alterId /etc/v2ray/config.json)"
    echo
    print ${GREEN} "Level: $(jq .inbounds[0].settings.clients[0].level /etc/v2ray/config.json)"
    echo
    print ${GREEN} "Protocol: VMess"
    echo
    print ${GREEN} "Install v2ary successful"
    echo
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



# Addition new v2ray protocol .
addition_protocol() {

    if [[ ! -f /etc/systemd/system/v2ray.service ]];then
        print ${RED} "You don't install v2ray please install v2ray first ."
    else
        systemctl stop v2ray
    fi

    while :;do
        echo
        print ${GREEN}  "1.Shadowsocks"
        echo
        print ${GREEN}  "2.Socks"
        echo
        print ${GREEN}  "3.Http"
        echo
        print ${GREEN}  "4.MTProto"
        echo
        print ${GREEN}  "5.Dokodemo-door"
        echo
        read -p "$(print ${BLUE} "请选择 V2Ray 传输协议 1 to 5: ")" protocol
        case ${protocol} in
        1)
#            aes-256-cfb
#            aes-128-cfb
#            chacha20
#            chacha20-ietf
#            aes-256-gcm
#            aes-128-gcm
#            chacha20-poly1305 或称 chacha20-ietf-poly1305
            declare -A map=(["1"]="aes-128-cfb" ["2"]="aes-256-cfb" ["3"]="chacha20" ["4"]="chacha20-ietf" ["5"]="chacha20-poly1305" ["6"]="aes-128-gcm" ["7"]="aes-256-gcm")
            config_protocol ${map}

            # Config port
            config_port "shadowsocks"

            # Config protocol
            config_protocol ${protocol}

            # Config password
            config_password "shadowsocks"
            echo "password: ${PASSWORD}"

            # Show config info
            break
        ;;

        2)
            break
        ;;
        3)
            break
        ;;
        4)
            break
        ;;
        5)
            break
        ;;
        *)
            print ${RED} "Please enter 1 to 5 ."
        ;;
        esac
    done


}

show_v2ray_config() {
    CONFIG_FILE="/etc/v2ray/config.json"
    if [[ ! -f ${CONFIG_FILE} ]];then
        print ${RED} "Maybe you don't install v2ray please check you v2ray status."
    fi
    local ID=$(jq .inbounds[0].settings.clients[0].id ${CONFIG_FILE})

    # Print install config info
    echo
    print ${GREEN} "Ip: ${IP}"
    echo
    print ${GREEN} "V2Ray port: $(jq .inbounds[0].port /etc/v2ray/config.json)"
    echo
	print ${GREEN} "UUID: ${ID//\"/}"
    echo
	print ${GREEN} "ExtraID: $(jq .inbounds[0].settings.clients[0].alterId ${CONFIG_FILE})"
    echo
    print ${GREEN} "Level: $(jq .inbounds[0].settings.clients[0].level ${CONFIG_FILE})"
    echo
    print ${GREEN} "Protocol: VMess"
    echo
    exit 0
}


while :; do

    print ${GREEN} "##############################################"
	echo
	print ${GREEN} "1.Install V2Ray"
	echo
	print ${GREEN} "2.Uninstall V2Ray"
	echo
	print ${GREEN} "3.Reinstall V2Ray"
	echo
	print ${GREEN} "4.Show v2ray config"
	echo
	print ${GREEN} "5.Addition new protocol"
	echo
	print ${GREEN} "Enter any key to exit ."
	echo
	print ${GREEN} "##############################################"
	read -p "$(print ${BLUE} "请选择 [1-5]:")" option
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
	    show_v2ray_config
	    break
	    ;;
	5)
	    addition_protocol
	    break
	    ;;
	*)
		exit 0
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
exit 0
