# Simple Squid 4.9 Installer for Debian
# Working for HTTPS payloads
# Open to remodify
#!/bin/bash
clear
cd
ln -fs /usr/share/zoneinfo/Asia/Manila /etc/localtime
export DEBIAN_FRONTEND=noninteractive

function ip_address(){
  local IP="$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )"
  [ -z "${IP}" ] && IP="$( wget -qO- -t1 -T2 ipv4.icanhazip.com )"
  [ -z "${IP}" ] && IP="$( wget -qO- -t1 -T2 ipinfo.io/ip )"
  [ ! -z "${IP}" ] && echo "${IP}" || echo
} 
IPADDR="$(ip_address)"

function BONV-MSG(){
 echo -e " Simple Squid 4.9 Installer for Debian"
 echo -e " Squid Source Patch by Diladele"
 echo -e ""
}

source /etc/os-release
if [[ "$ID" != 'debian' ]]; then
 echo -e "[\e[1;31mError\e[0m] This script is for Debian only, exting..." 
 exit 1
fi

if [[ $EUID -ne 0 ]];then
 BONV-MSG
 echo -e "[\e[1;31mError\e[0m] This script must be run as root, exiting..."
 exit 1
fi

rm -rf /root/.bash_history && history -c && echo '' > /var/log/syslog

clear
BONV-MSG
sleep 2
apt-get update
apt-get upgrade -y
apt-get install devscripts build-essential fakeroot debhelper dh-autoreconf dh-apparmor cdbs -y

apt-get install libcppunit-dev libsasl2-dev libxml2-dev libkrb5-dev libdb-dev libnetfilter-conntrack-dev libexpat1-dev libcap-dev libldap2-dev libpam0g-dev libgnutls28-dev libssl-dev libdbi-perl libecap3 libecap3-dev -y

if [[ -e /usr/bin/squid ]]; then
 apt-get remove --purge squid -y
 rm -rf /etc/squid
 rm -rf /usr/lib/squid
fi

rm -rf {control.patch,ecap.ver,rules.patch,squid.ver}
# wget -4q 'https://raw.githubusercontent.com/diladele/squid-ubuntu/master/src/ubuntu16/control.patch'
# wget -4q 'https://raw.githubusercontent.com/diladele/squid-ubuntu/master/src/ubuntu16/ecap.ver'
wget -4q 'https://raw.githubusercontent.com/diladele/squid-ubuntu/master/src/ubuntu18/scripts.squid4/rules.patch'
wget -4q 'https://raw.githubusercontent.com/diladele/squid-ubuntu/master/src/ubuntu18/scripts.squid4/squid.ver'

rm -rf build/squid
mkdir -p build/squid
cp rules.patch build/squid/rules.patch
source squid.ver
pushd build/squid

wget -4 "http://http.debian.net/debian/pool/main/s/squid/squid_${SQUID_PKG}.dsc"
wget -4 "http://http.debian.net/debian/pool/main/s/squid/squid_${SQUID_VER}.orig.tar.gz"
wget -4 "http://http.debian.net/debian/pool/main/s/squid/squid_${SQUID_VER}.orig.tar.gz.asc"
wget -4 "http://http.debian.net/debian/pool/main/s/squid/squid_${SQUID_PKG}.debian.tar.xz"
dpkg-source -x squid_${SQUID_PKG}.dsc
patch squid-${SQUID_VER}/debian/rules < ../../rules.patch
cd squid-${SQUID_VER}
dpkg-buildpackage -rfakeroot -b -us -uc
popd
pushd build/squid
apt-get install squid-langpack -y
dpkg --install squid-common_${SQUID_PKG}_all.deb
dpkg --install squid_${SQUID_PKG}_amd64.deb
dpkg --install squidclient_${SQUID_PKG}_amd64.deb
popd


rm -rf _acceptance
mkdir _acceptance
cp build/squid/squid*.deb _acceptance/
cp build/squid/squid*.ddeb _acceptance/

cat <<EOF> /etc/squid/squid.conf
acl VPN dst $IPADDR/32
http_access allow VPN
http_access deny all 
http_port 8050
http_port 8051
coredump_dir /dev/null
refresh_pattern ^ftp: 1440 20% 10080
refresh_pattern ^gopher: 1440 0% 1440
refresh_pattern -i (/cgi-bin/|\?) 0 0% 0
refresh_pattern . 0 20% 4320
visible_hostname localhost
EOF

service squid restart
clear
echo -e ""
echo -e "\e[1;32m Try now connecting to your squid proxy using port 8050 and 8051\e[0m"

exit 1
