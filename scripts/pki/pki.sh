#!/usr/bin/env bash
set -eu

openssl ecparam -genkey -name prime256v1 -out ca.key
openssl req -new -x509 -key ca.key -days 36500 -subj '/CN=karmada' -out ca.crt

openssl ecparam -genkey -name prime256v1 -out server.key
openssl req -new -key server.key -subj '/O=system:masters/CN=system:admin' -addext 'subjectAltName = DNS:kubernetes.default.svc, DNS:*.etcd.karmada-system.svc.cluster.local, DNS:*.karmada-system.svc.cluster.local, DNS:*.karmada-system.svc, DNS:localhost, IP:127.0.0.1' \
  | openssl x509 -req -copy_extensions copy -days 36500 -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt

openssl ecparam -genkey -name prime256v1 -out front.key
openssl req -new -key front.key -subj '/O=system:masters/CN=system:admin' \
  | openssl x509 -req -copy_extensions copy -days 36500 -CA ca.crt -CAkey ca.key -CAcreateserial -out front.crt

openssl ecparam -genkey -name prime256v1 -out etcd.key
openssl req -new -key etcd.key -subj '/CN=karmada-etcd' -addext 'subjectAltName = IP: 127.0.0.1, IP: 10.11.0.1, IP: 10.11.0.2, IP: 10.11.0.3, IP: 10.11.0.4, IP: 10.11.0.5, IP: 10.11.0.6, IP: 10.11.0.7, IP: 10.11.0.8, IP: 10.11.0.9, IP: 10.11.0.10, IP: 10.11.0.11, IP: 10.11.0.12, IP: 10.11.0.13, IP: 10.11.0.14, IP: 10.11.0.15, IP: 10.11.0.16, IP: 10.11.0.17, IP: 10.11.0.18, IP: 10.11.0.19, IP: 10.11.0.20, IP: 10.11.0.21, IP: 10.11.0.22, IP: 10.11.0.23, IP: 10.11.0.24, IP: 10.11.0.25, IP: 10.11.0.26, IP: 10.11.0.27, IP: 10.11.0.28, IP: 10.11.0.29, IP: 10.11.0.30, IP: 10.11.0.31, IP: 10.11.0.32, IP: 10.11.0.33, IP: 10.11.0.34, IP: 10.11.0.35, IP: 10.11.0.36, IP: 10.11.0.37, IP: 10.11.0.38, IP: 10.11.0.39, IP: 10.11.0.40, IP: 10.11.0.41, IP: 10.11.0.42, IP: 10.11.0.43, IP: 10.11.0.44, IP: 10.11.0.45, IP: 10.11.0.46, IP: 10.11.0.47, IP: 10.11.0.48, IP: 10.11.0.49, IP: 10.11.0.50, IP: 10.11.0.51, IP: 10.11.0.52, IP: 10.11.0.53, IP: 10.11.0.54, IP: 10.11.0.55, IP: 10.11.0.56, IP: 10.11.0.57, IP: 10.11.0.58, IP: 10.11.0.59, IP: 10.11.0.60, IP: 10.11.0.61, IP: 10.11.0.62, IP: 10.11.0.63, IP: 10.11.0.64, IP: 10.11.0.65, IP: 10.11.0.66, IP: 10.11.0.67, IP: 10.11.0.68, IP: 10.11.0.69, IP: 10.11.0.70, IP: 10.11.0.71, IP: 10.11.0.72, IP: 10.11.0.73, IP: 10.11.0.74, IP: 10.11.0.75, IP: 10.11.0.76, IP: 10.11.0.77, IP: 10.11.0.78, IP: 10.11.0.79, IP: 10.11.0.80, IP: 10.11.0.81, IP: 10.11.0.82, IP: 10.11.0.83, IP: 10.11.0.84, IP: 10.11.0.85, IP: 10.11.0.86, IP: 10.11.0.87, IP: 10.11.0.88, IP: 10.11.0.89, IP: 10.11.0.90, IP: 10.11.0.91, IP: 10.11.0.92, IP: 10.11.0.93, IP: 10.11.0.94, IP: 10.11.0.95, IP: 10.11.0.96, IP: 10.11.0.97, IP: 10.11.0.98, IP: 10.11.0.99, IP: 10.11.0.100, IP: 10.11.0.101, IP: 10.11.0.102, IP: 10.11.0.103, IP: 10.11.0.104, IP: 10.11.0.105, IP: 10.11.0.106, IP: 10.11.0.107, IP: 10.11.0.108, IP: 10.11.0.109, IP: 10.11.0.110, IP: 10.11.0.111, IP: 10.11.0.112, IP: 10.11.0.113, IP: 10.11.0.114, IP: 10.11.0.115, IP: 10.11.0.116, IP: 10.11.0.117, IP: 10.11.0.118, IP: 10.11.0.119, IP: 10.11.0.120, IP: 10.11.0.121, IP: 10.11.0.122, IP: 10.11.0.123, IP: 10.11.0.124, IP: 10.11.0.125, IP: 10.11.0.126, IP: 10.11.0.127, IP: 10.11.0.128, IP: 10.11.0.129, IP: 10.11.0.130, IP: 10.11.0.131, IP: 10.11.0.132, IP: 10.11.0.133, IP: 10.11.0.134, IP: 10.11.0.135, IP: 10.11.0.136, IP: 10.11.0.137, IP: 10.11.0.138, IP: 10.11.0.139, IP: 10.11.0.140, IP: 10.11.0.141, IP: 10.11.0.142, IP: 10.11.0.143, IP: 10.11.0.144, IP: 10.11.0.145, IP: 10.11.0.146, IP: 10.11.0.147, IP: 10.11.0.148, IP: 10.11.0.149, IP: 10.11.0.150, IP: 10.11.0.151, IP: 10.11.0.152, IP: 10.11.0.153, IP: 10.11.0.154, IP: 10.11.0.155, IP: 10.11.0.156, IP: 10.11.0.157, IP: 10.11.0.158, IP: 10.11.0.159, IP: 10.11.0.160, IP: 10.11.0.161, IP: 10.11.0.162, IP: 10.11.0.163, IP: 10.11.0.164, IP: 10.11.0.165, IP: 10.11.0.166, IP: 10.11.0.167, IP: 10.11.0.168, IP: 10.11.0.169, IP: 10.11.0.170, IP: 10.11.0.171, IP: 10.11.0.172, IP: 10.11.0.173, IP: 10.11.0.174, IP: 10.11.0.175, IP: 10.11.0.176, IP: 10.11.0.177, IP: 10.11.0.178, IP: 10.11.0.179, IP: 10.11.0.180, IP: 10.11.0.181, IP: 10.11.0.182, IP: 10.11.0.183, IP: 10.11.0.184, IP: 10.11.0.185, IP: 10.11.0.186, IP: 10.11.0.187, IP: 10.11.0.188, IP: 10.11.0.189, IP: 10.11.0.190, IP: 10.11.0.191, IP: 10.11.0.192, IP: 10.11.0.193, IP: 10.11.0.194, IP: 10.11.0.195, IP: 10.11.0.196, IP: 10.11.0.197, IP: 10.11.0.198, IP: 10.11.0.199, IP: 10.11.0.200, IP: 10.11.0.201, IP: 10.11.0.202, IP: 10.11.0.203, IP: 10.11.0.204, IP: 10.11.0.205, IP: 10.11.0.206, IP: 10.11.0.207, IP: 10.11.0.208, IP: 10.11.0.209, IP: 10.11.0.210, IP: 10.11.0.211, IP: 10.11.0.212, IP: 10.11.0.213, IP: 10.11.0.214, IP: 10.11.0.215, IP: 10.11.0.216, IP: 10.11.0.217, IP: 10.11.0.218, IP: 10.11.0.219, IP: 10.11.0.220, IP: 10.11.0.221, IP: 10.11.0.222, IP: 10.11.0.223, IP: 10.11.0.224, IP: 10.11.0.225, IP: 10.11.0.226, IP: 10.11.0.227, IP: 10.11.0.228, IP: 10.11.0.229, IP: 10.11.0.230, IP: 10.11.0.231, IP: 10.11.0.232, IP: 10.11.0.233, IP: 10.11.0.234, IP: 10.11.0.235, IP: 10.11.0.236, IP: 10.11.0.237, IP: 10.11.0.238, IP: 10.11.0.239, IP: 10.11.0.240, IP: 10.11.0.241, IP: 10.11.0.242, IP: 10.11.0.243, IP: 10.11.0.244, IP: 10.11.0.245, IP: 10.11.0.246, IP: 10.11.0.247, IP: 10.11.0.248, IP: 10.11.0.249, IP: 10.11.0.250, IP: 10.11.0.251, IP: 10.11.0.252, IP: 10.11.0.253, IP: 10.11.0.254' \
  | openssl x509 -req -copy_extensions copy -days 36500 -CA ca.crt -CAkey ca.key -CAcreateserial -out etcd.crt

CA_KEY="$(cat ca.key | sed 's/^/              /')"
CA_CRT="$(cat ca.crt | sed 's/^/              /')"
SERVER_KEY="$(cat server.key | sed 's/^/              /')"
SERVER_CRT="$(cat server.crt | sed 's/^/              /')"
FRONT_KEY="$(cat front.key | sed 's/^/              /')"
FRONT_CRT="$(cat front.crt | sed 's/^/              /')"
ETCD_CA_CRT="$(cat ca.crt | sed 's/^/                /')"
ETCD_KEY="$(cat etcd.key | sed 's/^/                /')"
ETCD_CRT="$(cat etcd.crt | sed 's/^/                /')"

cat <<EOF
      karmada-certs: |
        certs:
          custom:
            caCrt: |
$CA_CRT
            caKey: |
$CA_KEY
            crt: |
$SERVER_CRT
            key: |
$SERVER_KEY
            frontProxyCaCrt: |
$CA_CRT
            frontProxyCrt: |
$FRONT_CRT
            frontProxyKey: |
$FRONT_KEY
        etcd:
          external:
            certs:
              caCrt: |
$ETCD_CA_CRT
              crt: |
$ETCD_CRT
              key: |
$ETCD_KEY
EOF

