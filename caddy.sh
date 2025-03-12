#!/bin/bash

# Step 1: Set ZTN_IP in .bashrc from the ztn0 interface
echo "ZTN_IP=$(ifconfig ztn0 | grep 'inet ' | awk '{print $2}')" >> ~/.bashrc  && source ~/.bashrc

# Step 2: Add the Caddy repository key
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg

# Step 3: Add the Caddy stable repository to sources list
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list

# Step 4: Update the apt package list
sudo apt update

# Step 5: Install Caddy
sudo apt install caddy

# Step 6: Check the Caddy version
caddy -v

# Step 7: Get the value of ZTN_IP from .bashrc
ZTN_IP=$(grep ZTN_IP ~/.bashrc | cut -d'=' -f2)

# Step 8: Update the Caddyfile with the ZTN_IP value
sudo tee /etc/caddy/Caddyfile <<EOF
### flink-prod-1 ###
http://${ZTN_IP}:81 {
  tls internal
  reverse_proxy http://3.82.121.245:8081 {
    header_up X-Real-IP {remote}
    header_up X-Forwarded-For {remote}
    header_up X-Forwarded-Proto {scheme}
  }
  log {
    output file /var/log/caddy/access-81.log
  }
}

### flink-prod-1 ###
http://${ZTN_IP}:82 {
  tls internal
  reverse_proxy http://3.82.121.245:8082 {
    header_up X-Real-IP {remote}
    header_up X-Forwarded-For {remote}
    header_up X-Forwarded-Proto {scheme}
  }
  log {
    output file /var/log/caddy/access-82.log
  }
}

### flink-prod-2 ###
http://${ZTN_IP}:83 {
  tls internal
  reverse_proxy http://40.172.186.166:8081 {
    header_up X-Real-IP {remote}
    header_up X-Forwarded-For {remote}
    header_up X-Forwarded-Proto {scheme}
  }
  log {
    output file /var/log/caddy/access-83.log
  }
}
EOF

echo "Caddyfile updated successfully."

# Restart Caddy to apply the changes
sudo systemctl restart caddy

# Firewall configuration file path
FIREWALLD_FILE="/etc/firewalld/zones/trusted.xml"

# Create the trusted.xml file with firewall configuration
cat <<EOF | tee "$FIREWALLD_FILE"
<?xml version="1.0" encoding="utf-8"?>
<zone target="ACCEPT">
  <short>Trusted</short>
  <description>All network connections are accepted.</description>
  <source address="172.31.252.1"/>
  <source address="172.31.252.2"/>
</zone>
EOF

# Define the ZTN configuration file path
ZTN_CONFIG_FILE="/etc/ztn/config.yaml"

# Append the required configuration to /etc/ztn/config.yaml
echo -e "    - port: 81\n      proto: tcp\n      groups:\n        - ssh" | tee -a "$ZTN_CONFIG_FILE"
echo -e "    - port: 82\n      proto: tcp\n      groups:\n        - ssh" | tee -a "$ZTN_CONFIG_FILE"
echo -e "    - port: 83\n      proto: tcp\n      groups:\n        - ssh" | tee -a "$ZTN_CONFIG_FILE"
echo -e "    - port: 84\n      proto: tcp\n      groups:\n        - ssh" | tee -a "$ZTN_CONFIG_FILE"

# Restart firewalld to apply changes
sudo systemctl restart firewalld

# Restart ztn service to apply changes
sudo systemctl restart ztn

echo "Firewall and ZTN configuration updated and services restarted."
