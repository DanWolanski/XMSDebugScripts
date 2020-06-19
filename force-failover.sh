iptables -F 
iptables -I INPUT -p tcp -m state --state NEW,ESTABLISHED -j REJECT --reject-with tcp-reset
iptables -I OUTPUT -p tcp -m state --state NEW,ESTABLISHED -j REJECT --reject-with tcp-reset
iptables -I FORWARD -p tcp -m state --state NEW,ESTABLISHED -j REJECT --reject-with tcp-reset
iptables -I INPUT -p udp -j REJECT --reject-with icmp-port-unreachable
iptables -I OUTPUT -p udp -j REJECT --reject-with icmp-port-unreachable
iptables -I FORWARD -p udp -j REJECT --reject-with icmp-port-unreachable
sleep 60s
iptables -D INPUT -p tcp -m state --state NEW,ESTABLISHED -j REJECT --reject-with tcp-reset
iptables -D OUTPUT -p tcp -m state --state NEW,ESTABLISHED -j REJECT --reject-with tcp-reset
iptables -D FORWARD -p tcp -m state --state NEW,ESTABLISHED -j REJECT --reject-with tcp-reset
iptables -D INPUT -p udp -j REJECT --reject-with icmp-port-unreachable
iptables -D OUTPUT -p udp -j REJECT --reject-with icmp-port-unreachable
iptables -D FORWARD -p udp -j REJECT --reject-with icmp-port-unreachable
