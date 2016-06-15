#!/bin/bash
echo -n "Sip ports 5060/tcp - "
firewall-cmd --zone=public --add-port=5060/tcp --permanent
echo -n "Sip ports 5060/udp - "
firewall-cmd --zone=public --add-port=5060/udp --permanent

echo -n "Audio RTP/RTCP ports 49152-53152/udp - "
firewall-cmd --zone=public --add-port=49152-53152/udp --permanent
echo -n "Video RTP/RTCP ports 57344-61344/udp - " 
firewall-cmd --zone=public --add-port=57344-61344/udp --permanent

echo -n "https for webui 443-444/tcp - "
firewall-cmd --zone=public --add-port=443-444/tcp --permanent

echo -n "WebRTC port: 1080/tcp - "
firewall-cmd --zone=public --add-port=1080/tcp --permanent
echo -n "MSRP default port 2855/tcp" - 
firewall-cmd --zone=public --add-port=2855/tcp --permanent
echo -n "REST service port 81/tcp -"
firewall-cmd --zone=public --add-port=81/tcp --permanent
echo -n "ports 56000-56999/udp -"
firewall-cmd --zone=public --add-port=56000-56999/udp --permanent



echo -n "SNMP Port 161-162/udp - "
firewall-cmd --zone=public --add-port=161-162/udp --permanent

echo -n "Web/REST Admin https 10443/tcp - "
firewall-cmd --zone=public --add-port=10443/tcp --permanent

#MRB ports
echo -n "MRB adapter ports 12000-12010/tcp - "
firewall-cmd --zone=public --add-port=12000-12010/tcp --permanent

#MRB Ports for MRB Server
echo -n "MRB adapter ports 8888/tcp - "
firewall-cmd --zone=public --add-port=8888/tcp --permanent
echo -n "MRB adapter ports 8443/tcp - "
firewall-cmd --zone=public --add-port=8443/tcp --permanent
echo -n "MRB adapter ports 5070/tcp - "
firewall-cmd --zone=public --add-port=5070/tcp --permanent
echo -n "MRB adapter ports 5100/udp - "
firewall-cmd --zone=public --add-port=5100/udp --permanent
echo -n "MRB adapter ports 5100/tcp - "
firewall-cmd --zone=public --add-port=5100/tcp --permanent
echo -n "MRB adapter ports 5111/tcp - "
firewall-cmd --zone=public --add-port=5111/tcp --permanent

echo "Restarting firewalld.service to apply - "
systemctl restart firewalld.service

echo "New Firewall settings are:"
firewall-cmd --list-all

echo "Operation complete!"

