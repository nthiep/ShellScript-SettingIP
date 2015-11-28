#!/bin/bash
##################################################
# Name: configuration.sh
# Description: File cau hinh ip va lay dia chi ip tren remote host
#
##################################################
# Set Script Variables
#
# dia chi file cau hinh Debian hoac Ubuntu
#NETWORK_CONFIG_DEBIAN="/home/hiep/kichban/TieuLuanKB/ConfigFile/interfaces"
NETWORK_CONFIG_DEBIAN="/etc/network/interfaces"
# dia chi file cau hinh tren redhat fedora centos
NETWORK_CONFIG_REDHAT="/etc/sysconfig/network-scripts/ifcfg-"
# NETWORK_CONFIG_REDHAT="/home/hiep/kichban/TieuLuanKB/ConfigFile/ifcfg-"
# dia chi file luu lai cac buoc cau hinh
LOG_FILE="settingIpLog.txt"
##################################################
# Ham lay dia chi ip tu lenh ifconfig neu hien tai dang su dung ip dong
#
getIfconfigInfo(){
	[ $# -eq 0 ] && return 1
	ip=$(ifconfig $1  2> /dev/null|grep "inet addr"|cut -f 2 -d ":"|cut -f 1 -d " ")
	netmask=$(ifconfig $1  2> /dev/null|grep "Mask"|cut -f 4 -d ":")
	[ -n "$ip" -a -n "$netmask" ] && echo "dhcp:$ip:$netmask" || echo ""
}
# Ham lay dia chi default gateway
#
getDefaultGateway(){
	[ -n "$(route |grep UG|sed -e 's/[[:space:]]\+/ /g'|cut -f2 -d' ')" ] || echo "-"
}

# Ham dat default gateway
#
setDefaultGateway(){
	[ $# -eq 0 ] && return 1
	oldgateway=$(getDefaultGateway)
	[ -n "$oldgateway" ] && route del default gw $oldgateway
	route add default gw $1
}

##################################################
# Ham lay dia chi ip tu lenh ifconfig neu hien tai dang su dung ip dong
# hoac tu file cau hinh tren may Redhat centos
#
getIpInfoRedhat(){
	echo "config getIpInfoRedhat: $1" >> $LOG_FILE	
	[ -f "$NETWORK_CONFIG_REDHAT$1" ] || { getIfconfigInfo $1; return 1; }
	[ $# -eq 0 ] && return 1
	ip=$(sed -n 's/IPADDR=//p'  $NETWORK_CONFIG_REDHAT$1|sed -e 's/^[[:space:]]*//')
	netmask=$(sed -n 's/NETMASK=//p'  $NETWORK_CONFIG_REDHAT$1|sed -e 's/^[[:space:]]*//')

	echo "config getIpInfoRedhat: ip:$ip" >> $LOG_FILE
	echo "config getIpInfoRedhat: netmask:$netmask" >> $LOG_FILE
	[ -n "$ip" -a -n "$netmask" ] && { echo "$ip:$netmask"; return 0; }
	ipInfo=$(getIfconfigInfo $1)
	echo "config getIpInfoRedhat: ipInfo:$ipInfo" >> $LOG_FILE
	[ -n "$ipInfo" ] && echo $ipInfo || return 1
}

##################################################
# Ham lay string cau hinh static hay dhcp cho may debian
#
getConfigIfStringDebian(){
	[ "$2" == "dhcp" ] && printf '\\n'"auto $1"'\\n'"iface $1 inet dhcp"'\\n' || printf '\\n'"auto $1"'\\n'"iface $1 inet static"'\\n'
	return 0
}

##################################################
# Ham lay string cau hinh ip, netmask, gateway cho may debian
#
getConfigIpStringDebian(){
	[ -n "$1" ] && printf '\\t'"address $1"'\\n'
	[ -n "$2" ] && printf '\\t'"netmask $2"'\\n'
	[ -n "$3" ] && printf '\\t'"gateway $3"'\\n'
}

##################################################
# Ham cau hinh ip cho may debian
#
setIpDebian(){
	# Kiem tra neu file cau hinh chua tao hoac khong co interface cau hinh
	#
	[ -f "$NETWORK_CONFIG_DEBIAN" ] && grep -q "iface $1" $NETWORK_CONFIG_DEBIAN || \
	{ echo "iface $1" >> $NETWORK_CONFIG_DEBIAN; echo "config setIpDebian: Config file $1 not found" >> $LOG_FILE; }	
	
	# cau lenh sed xoa tat ca cac dong cau hinh trong interface
	#
	sed -i$(date +'_%m-%d-%Y_%k:%M:%S:%N_%Z%z').bak "/iface $1/,/iface/{//!d}" $NETWORK_CONFIG_DEBIAN
	
	# cau lenh sed cau hinh dhcp
	#
	[ "$2" == "dhcp" ] && { sed -i "s/iface $1.*/$(getConfigIfStringDebian $1 $2)/" $NETWORK_CONFIG_DEBIAN; return 0; }
	# ghi vao file log
	echo "s/iface $1.*/$(getConfigIfStringDebian $1 $2)$(getConfigIpStringDebian $3 $4 $5)/" >> $LOG_FILE 
	# cau lenh sed cau hinh static
	sed -i "s/iface $1.*/$(getConfigIfStringDebian $1 $2)$(getConfigIpStringDebian $3 $4 $5)/" $NETWORK_CONFIG_DEBIAN
	return 0

}

##################################################
# Ham cau hinh ip cho may redhat
#
setIpRedhat(){
	[ -f "$NETWORK_CONFIG_REDHAT$1" ] && cp $NETWORK_CONFIG_REDHAT$1 $NETWORK_CONFIG_REDHAT$1$(date +'_%m-%d-%Y_%k:%M:%S:%N_%Z%z').bak || echo "" > $NETWORK_CONFIG_REDHAT$1
	[ -n "$2" ] && { grep -q "^BOOTPROTO=" $NETWORK_CONFIG_REDHAT$1 && sed "s/^BOOTPROTO=.*/BOOTPROTO=$2/" -i $NETWORK_CONFIG_REDHAT$1 || sed "$ a\BOOTPROTO=$2" -i $NETWORK_CONFIG_REDHAT$1; }
	[ -n "$3" ] && { grep -q "^IPADDR=" $NETWORK_CONFIG_REDHAT$1 && sed "s/^IPADDR=.*/IPADDR=$3/" -i $NETWORK_CONFIG_REDHAT$1 || sed "$ a\IPADDR=$3" -i $NETWORK_CONFIG_REDHAT$1; }
	[ -n "$4" ] && { grep -q "^NETMASK=" $NETWORK_CONFIG_REDHAT$1 && sed "s/^NETMASK=.*/NETMASK=$4/" -i $NETWORK_CONFIG_REDHAT$1 || sed "$ a\NETMASK=$4" -i $NETWORK_CONFIG_REDHAT$1; }
	[ -n "$5" ] && { grep -q "^GATEWAY=" $NETWORK_CONFIG_REDHAT$1 && sed "s/^GATEWAY=.*/GATEWAY=$5/" -i $NETWORK_CONFIG_REDHAT$1 || sed "$ a\GATEWAY=$5" -i $NETWORK_CONFIG_REDHAT$1; }
}

##################################################
# Ham lay dia chi ip tren may debian
#
getIpInfoDebian(){
	[ $# -eq 0 ] && return 1
	# lay dhcp hay static	
	type=$(sed -n "/iface $1/,/iface/ s/iface $1 inet//p"  $NETWORK_CONFIG_DEBIAN|sed -e 's/^[[:space:]]*//')
	# lenh sed lay dia chi ip
	ip=$(sed -n "/iface $1/,/iface/ s/address//p"  $NETWORK_CONFIG_DEBIAN|sed -e 's/^[[:space:]]*//')
	# lenh sed lay subnetmask
	netmask=$(sed -n "/iface $1/,/iface/ s/netmask//p"  $NETWORK_CONFIG_DEBIAN|sed -e 's/^[[:space:]]*//')
	# lenh sed lay default gateway
	gateway=$(sed -n "/iface $1/,/iface/ s/gateway//p"  $NETWORK_CONFIG_DEBIAN|sed -e 's/^[[:space:]]*//')
	# ghi log file
	echo "config getIpInfoDebian: Type:$type" >> $LOG_FILE
	echo "config getIpInfoDebian: IP:$ip" >> $LOG_FILE
	echo "config getIpInfoDebian: netmask:$netmask" >> $LOG_FILE
	echo "config getIpInfoDebian: gateway:$gateway" >> $LOG_FILE
	# kiem tra ip co ton tai trong file cau hinh
	[ -n "$ip" -a -n "$netmask" ] && { echo "$type:$ip:$netmask:$gateway"; return 0; }
	# lay dia chi ip tu lenh ifconfig
	ipInfo=$(getIfconfigInfo $1)
	# ghi log file
	echo "config getIpInfoDebian: ipInfo:$ipInfo" >> $LOG_FILE
	[ -n "$ipInfo" ] && echo $ipInfo || echo "dhcp:-:-:-"
}

##################################################
# Ham kiem tra phien ban he dieu hanh co phai Debian hay Ubuntu
#
isDebianOS(){
	local VERSION_FILE="/proc/version"
	version=$(cat $VERSION_FILE)
	[[ "$version" == *"ubuntu"* ]] || [[ "$version" == *"debian"* ]] \
	&& { echo "config isDebianOS: Debian OS" >> $LOG_FILE; return 0; } \
	|| { echo "config isDebianOS: Not Debian OS" >> $LOG_FILE; return 1; }
}

##################################################
# Cau hinh IP
#
settingIp(){
	result=$(isDebianOS && setIpDebian $1 $2 $3 $4 $5 || setIpRedhat $1 $2 $3 $4 $5)
	ifdown $1 && ifup $1
	echo "config settingIp: $result" >> $LOG_FILE; 
}

##################################################
# Lay thong tin IP cu
#
getInfoIp(){
	# nau may la Debian hay Ubuntu thi goi ham getIpInfoDebian
	# neu khong -> goi getIpInfoRedhat
	isDebianOS && result=$(getIpInfoDebian $1) || result=$(getIpInfoRedhat $1)
	echo $result
	echo "config getInfoIp: $result" >> $LOG_FILE; 
}

##################################################
# Ham main
#
main(){
	old=$(getInfoIp $3)
	oldGateway=$(getDefaultGateway)
	[ -n "$oldgateway" ] || oldgateway="-"
	[ "$2" == "-" ] || setDefaultGateway $2
	[ "$4" == "static" -o "$4" == "dhcp" ] && settingIp $3 $4 $5 $6 $7 \
	&& echo  $1:$oldGateway:$2:$3:$old:$4:$5:$6:$7\
	|| echo  $1:$oldGateway:$2:$3:$old:-:-:-:-:-
}
echo "**********" $(date -R) >> $LOG_FILE
echo "config value: $1 $2 $3 $4 $5 $6 $7" >> $LOG_FILE
result=$(main $1 $2 $3 $4 $5 $6 $7)
echo $result
echo "config result: $result" >> $LOG_FILE