#!/bin/ash

if [ "$(nc -z "$(hostname -i)" 3128; echo $?)" -ne 0 ]; then
   echo "HTTP proxy port 3128 is not responding"
   exit 1
fi

if [ "$(nc -z "$(hostname -i)" 3129; echo $?)" -ne 0 ]; then
   echo "HTTP proxy port 3129 is not responding"
   exit 1
fi

if [ "$(ip -o addr | grep "$(hostname -i)" | wc -l)" -eq 0 ]; then
   echo "NIC missing"
   exit 1
fi

echo "HTTP proxy ports 3128 and 3129 responding OK"
exit 0