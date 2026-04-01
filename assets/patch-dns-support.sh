#!/bin/sh
#
# Patch Duo Authentication Proxy to support DNS hostnames in [radius_client] host parameter.
#
# By default, Duo Auth Proxy only accepts IP addresses for the host parameter.
# This patch adds hostname resolution support so Docker service names can be used.
#
# Modifies:
#   - lib/ip_util.py: Accept valid hostnames in addition to IP addresses
#   - lib/util.py: Resolve hostnames to IP addresses in get_addr_port_pairs()
#

set -eu

BASE_PATH="${1:?Usage: $0 <duoauthproxy-src-path>}"

IP_UTIL="$BASE_PATH/pkgs/duoauthproxy/duoauthproxy/lib/ip_util.py"
UTIL="$BASE_PATH/pkgs/duoauthproxy/duoauthproxy/lib/util.py"

# Verify files exist
for f in "$IP_UTIL" "$UTIL"; do
    [ -f "$f" ] || { echo "ERROR: $f not found"; exit 1; }
done

# --- Patch ip_util.py ---

TMPFILE=$(mktemp)

awk '
/^def is_valid_single_ip\(ip_string\):$/ {
    print "def is_valid_hostname(hostname):"
    print "    \"\"\"Check if hostname is a valid DNS name (RFC 1123).\"\"\""
    print "    import re"
    print "    if not hostname or len(hostname) > 253:"
    print "        return False"
    print "    if hostname.endswith(\".\"):"
    print "        hostname = hostname[:-1]"
    print "    pattern = re.compile(r\"^[a-zA-Z0-9]([a-zA-Z0-9_\\\\-]{0,61}[a-zA-Z0-9])?$\")"
    print "    return all(pattern.match(label) for label in hostname.split(\".\"))"
    print ""
    print ""
    print $0
    next
}
/elif netaddr\.valid_ipv6\(ip_string\):/ {
    print $0
    getline
    print $0
    print "        elif is_valid_hostname(ip_string):"
    print "            return True"
    next
}
{ print }
' "$IP_UTIL" > "$TMPFILE" && mv "$TMPFILE" "$IP_UTIL"

echo "Patched $IP_UTIL"

# --- Patch util.py ---

TMPFILE=$(mktemp)

awk '
/^def get_addr_port_pairs\(config\):$/ {
    print "def _resolve_host(host):"
    print "    \"\"\"Resolve hostname to IP address. Pass through if already an IP.\"\"\""
    print "    import socket"
    print "    import netaddr"
    print "    if netaddr.valid_ipv4(host, flags=netaddr.core.INET_PTON) or netaddr.valid_ipv6(host):"
    print "        return host"
    print "    try:"
    print "        result = socket.getaddrinfo(host, None, socket.AF_UNSPEC, socket.SOCK_DGRAM)"
    print "        if result:"
    print "            resolved_ip = result[0][4][0]"
    print "            log.msg(\"Resolved hostname \x27{}\x27 to IP \x27{}\x27\".format(host, resolved_ip))"
    print "            return resolved_ip"
    print "    except socket.gaierror as e:"
    print "        raise ConfigError(\"Could not resolve hostname \x27{}\x27: {}\".format(host, e))"
    print "    raise ConfigError(\"Could not resolve hostname \x27{}\x27\".format(host))"
    print ""
    print ""
    print $0
    next
}
/config\.get_str\(host_key\),/ {
    gsub(/config\.get_str\(host_key\)/, "_resolve_host(config.get_str(host_key))")
    print
    next
}
{ print }
' "$UTIL" > "$TMPFILE" && mv "$TMPFILE" "$UTIL"

echo "Patched $UTIL"
echo "DNS hostname support patched successfully."
