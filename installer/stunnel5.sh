#!/bin/bash

#install haproxy ssl
apt install haproxy -y
rm -fr /etc/haproxy/haproxy.cfg
cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/funny.pem
chmod 600 /etc/haproxy/funny.pem
cat >/etc/haproxy/haproxy.cfg <<HAH
global
    daemon
    maxconn 256
    log /dev/log local0

defaults
    mode http
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms

frontend ssh-ssl
    bind *:777 ssl crt /etc/haproxy/funny.pem
    mode tcp
    option tcplog
    # Found 514: ssh-online maps 777 sessions to real client IPs by matching
    # the accept timestamp with the Dropbear child. Without logasap HAProxy
    # logs only when the session closes, so active sessions have no evidence.
    option logasap
    log global
    default_backend ssh-backend

backend ssh-backend
    mode tcp
    server ssh-server 127.0.0.1:109
HAH
clear
echo ""
echo ""
systemctl enable haproxy
systemctl restart haproxy

rm -f /root/stunnel5.sh
