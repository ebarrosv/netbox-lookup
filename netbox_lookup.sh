#!/bin/bash

NETBOX_URL="http://192.168.150.212:8000"
API_TOKEN="0b5f9c22b746485c176ec5c4a22f81b0d430527a"

if [ -z "$1" ]; then
    echo "Usage: $0 <ip_file>"
    echo "Or: echo '190.112.102.90' | $0 -"
    exit 1
fi

# Get all prefixes from NetBox
curl -s -H "Authorization: Token $API_TOKEN" "$NETBOX_URL/api/ipam/prefixes/?limit=500" > /tmp/netbox_prefixes.json

# Read IPs
if [ "$1" = "-" ]; then
    ips=$(cat)
else
    ips=$(cat "$1")
fi

# Run Python to match IPs
python3 - "$ips" << 'PYEOF'
import json
import ipaddress
import sys

ips_data = sys.argv[1]
user_ips = [line.strip() for line in ips_data.split('\n') if line.strip()]

with open('/tmp/netbox_prefixes.json') as f:
    data = json.load(f)

nets = {}
for r in data['results']:
    prefix = r.get('prefix')
    if prefix and '/' in prefix:
        network = ipaddress.ip_network(prefix, strict=False)
        if network.prefixlen >= 21:
            nets[network] = r.get('description', '')

for ip_str in user_ips:
    ip = ipaddress.ip_address(ip_str)
    best_match = None
    best_prefixlen = 0
    for net, desc in nets.items():
        if ip in net and net.prefixlen > best_prefixlen:
            best_match = desc
            best_prefixlen = net.prefixlen
    print(best_match if best_match else "NOT FOUND")
PYEOF
