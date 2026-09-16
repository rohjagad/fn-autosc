#!/bin/bash

#install haproxy ssl
apt install haproxy -y
rm -fr /etc/haproxy/haproxy.cfg
cat /etc/xray/xray.crt /etc/xray/xray.key | tee /etc/haproxy/funny.pem
cat >/etc/haproxy/haproxy.cfg <<HAH
global
    daemon
    maxconn 256

defaults
    mode http
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms

frontend ssh-ssl
    bind *:777 ssl crt /etc/haproxy/funny.pem
    mode tcp
    option tcplog
    default_backend ssh-backend

backend ssh-backend
    mode tcp
    option tcplog
    server ssh-server 127.0.0.1:109
HAH
clear

rm -f /root/stunnel5.sh