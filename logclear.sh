service nodecontroller stop
rm -f /var/log/xms/*
rm -f /var/log/dialogic/*
echo "Clearing syslog" > /var/log/messages
service nodecontroller start
