#!/bin/bash
##################################################
# Name: setting.sh
# Description: main setting file
#
##################################################
# Set Script Variables
#
DEFAULT_NETMASK="255.255.255.0"
SCRIP_FILE="configuration.sh"
SYSADMIN_USERNAME="hiep"
RESULT_FILE="result.txt"
LOG_FILE="settingIpLog.txt"
SSH_ERROR="Can not connect to host"

##################################################
# Ham kiem tra netmask
#
mask2cidr() {
	nbits=0
	local IFS=.
	for dec in $1 ; do
		case $dec in
			255) let nbits+=8;;
			254) let nbits+=7;;
			252) let nbits+=6;;
			248) let nbits+=5;;
			240) let nbits+=4;;
			224) let nbits+=3;;
			192) let nbits+=2;;
			128) let nbits+=1;;
			0);;
			*) return 1
		esac
	done
	return 0
}

##################################################
# Ham chuyen so sang subnetmask
#
cidr2mask() {
	local full_octets=$(($1/8))
	local partial_octet=$(($1%8))
	local i mask=""  
	for ((i=0;i<4;i+=1)); do
		if [ $i -lt $full_octets ]; then
			mask+=255
		elif [ $i -eq $full_octets ]; then
			mask+=$((256 - 2**(8-$partial_octet)))
		else
			mask+=0
		fi  
		test $i -lt 3 && mask+=.
	done
	echo $mask
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
# Ham kiem tra Subnet 
#
checkCidr(){
	case "$*" in
	""|*[!0-9]*) return 1 ;;
	esac
	(("$1">=0 && "$1"<=32)) && return 0
	return 1
}

##################################################
# Gan dia chi ip tu dong neu khong co 
#
getAutoIp(){
	local IFS=.
	[ $# -eq 4 ] || return 1
	set -- $*
	echo $1.$2.$3.$(($4+1))
}

##################################################
# Chuong trinh chinh 
#
main(){
	while IFS=: read thisHost thisIface thisStatus thisSetip thisSetnetmask thisSetgateway
	do
		echo "******** Setting ip for host $thisHost:$thisIface **********"
		echo "read file " $thisHost $thisIface $thisStatus $thisSetip $thisSetnetmask $thisSetgateway
		# kiem tra dia chi ip hoac hostname
		[ -n "$thisHost" ] && host=$thisHost
		# kiem tra interface
		[ -n "$thisIface" ] && iface=$thisIface
		# trang thai la static hay dhcp hay null
		[ -n "$thisStatus" ] && status=$thisStatus
		# kiem tra dia chi ip
		[ -n "$thisSetip" ] && isValidip $thisSetip && setip=$thisSetip || setip=$(getAutoIp $setip) 
		# kiem tra subnetmask
		[ -n "$thisSetnetmask" ] && setnetmask=$thisSetnetmask
		# kiem tra gateway
		[ -n "$thisSetgateway" ] && isValidip $thisSetgateway && setgateway=$thisSetgateway
		checkCidr $setnetmask && cidr2mask $setnetmask && setnetmask=$(cidr2mask $setnetmask) \
		|| mask2cidr $setnetmask || setnetmask=$DEFAULT_NETMASK
		###########
		echo "setting file " $host $iface $status $setip $setnetmask $setgateway
		# chay script cau hinh ip tren remote host
		ssh $SYSADMIN_USERNAME@$host 'bash -s' < $SCRIP_FILE $host $iface $status $setip $setnetmask $setgateway >> $RESULT_FILE
		# doc file log va xoa
		ssh $SYSADMIN_USERNAME@$host "cat $LOG_FILE ; rm $LOG_FILE" < /dev/null >> $LOG_FILE 
	done < "$1"
}

usage(){
	cat README.md
	exit 0
}
[ $# -eq 0 ]  && usage
main $1