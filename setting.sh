#!/bin/bash
##################################################
# Name: setting.sh
# Description: main setting file
# Kich ban:
# - co file cau hinh gom danh sach may va cac thuoc tinh
# - DiaChiHost:[DefaultGateway]:[Cardmang:[static/dhcp]:[diachiIP]:[Subnetmask]:[Gateway]]
# - de dat default gateway
# - DiaChiHost:DefaultGateway
# ket qua file
# ipaddress:OldGateway:NewGateway:interface:oldtype:oldip:oldnetmask:oldgateway:newtype:newip:newnetmask:newgateway
##################################################
# Set Script Variables
#
DEFAULT_NETMASK="255.255.255.0"
SCRIP_FILE="configuration.sh"
SYSADMIN_USERNAME="root"
RESULT_FILE="result.txt"
LOG_FILE="settingIpLog.txt"
SSH_ERROR="Can not connect to host"
##################################################
# Gan dia chi ip tu dong neu khong co 
#
getAutoIp(){
	local IFS=.
	set -- $*
	[ $# -eq 4 ] || return 1
	[ $4 -lt 254 ] && { echo $1.$2.$3.$(($4+1)); return 0; }	
	[ $3 -lt 254 ] && { echo $1.$2.$(($3+1)).1; return 0; }
	[ $2 -lt 254 ] && { echo $1.$(($2+1)).0.1; return 0; }	
	[ $1 -lt 254 ] && { echo $(($1+1)).0.0.1; return 0; } || return 1
}
##################################################
# Ham kiem tra dia chi ip
#
isValidip(){
	case "$*" in
	""|*[!0-9.]*|*[!0-9]) return 1 ;;
	esac

	local IFS=.
	set -- $*

	[ $# -eq 4 ] &&
	[ ${1:-666} -le 255 ] && [ ${2:-666} -le 255 ] &&
	[ ${3:-666} -le 255 ] && [ ${4:-666} -le 254 ]
}

##################################################
# Chuong trinh chinh 
#
main(){
	while IFS=: read thisHost thisDefaultGateway thisIface thisType thisSetip thisSetnetmask thisSetgateway
	do
		echo "******** Setting ip for host $thisHost:$thisIface **********"
		echo "setgateway $thisDefaultGateway"
		echo "read file " $thisHost $thisDefaultGateway $thisIface $thisType $thisSetip $thisSetnetmask $thisSetgateway
		# kiem tra dia chi ip hoac hostname
		[ -n "$thisHost" ] && host=$thisHost || continue
		# kiem tra default gateway
		[ -n "$thisDefaultGateway" ] && isValidip && defaultGateway=$thisDefaultGateway || defaultGateway="-"
		# kiem tra interface
		[ -n "$thisIface" ] && iface=$thisIface
		# trang thai la static hay dhcp hay null
		[ -n "$thisType" ] && type=$thisType
		# kiem tra dia chi ip
		[ -n "$thisSetip" ] && isValidip $thisSetip && setip=$thisSetip || setip=$(getAutoIp $setip) 
		# kiem tra subnetmask
		[ -n "$thisSetnetmask" ] && setnetmask=$thisSetnetmask
		# kiem tra gateway
		[ -n "$thisSetgateway" ] && isValidip $thisSetgateway && setgateway=$thisSetgateway
		###########
		echo "setting file " $host $defaultGateway $iface $type $setip $setnetmask $setgateway
		# chay script cau hinh ip tren remote host
		ssh $SYSADMIN_USERNAME@$host 'bash -s' < $SCRIP_FILE $host $defaultGateway $iface $type $setip $setnetmask $setgateway >> $RESULT_FILE
		# doc file log va xoa
		# < /dev/null hoac -n; dung chuyen huong stdin cua ssh vao /dev/null
		ssh $SYSADMIN_USERNAME@$host "cat $LOG_FILE ; rm $LOG_FILE" < /dev/null >> $LOG_FILE 
	done < "$1"
}

usage(){
	cat README.md
	exit 0
}
[ $# -eq 0 ]  && usage
main $1
