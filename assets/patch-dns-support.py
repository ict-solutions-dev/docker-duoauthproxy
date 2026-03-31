#!/usr/bin/env python3
"""
Patch Duo Authentication Proxy to support DNS hostnames in [radius_client] host parameter.

By default, Duo Auth Proxy only accepts IP addresses for the host parameter.
This patch adds hostname resolution support so Docker service names can be used.

Modifies:
  - lib/ip_util.py: Accept valid hostnames in addition to IP addresses
  - lib/util.py: Resolve hostnames to IP addresses in get_addr_port_pairs()
"""

import os
import sys


def patch_ip_util(base_path):
    """Patch ip_util.py to accept hostnames in is_valid_single_ip()."""
    filepath = os.path.join(
        base_path, "pkgs/duoauthproxy/duoauthproxy/lib/ip_util.py"
    )

    with open(filepath, "r") as f:
        content = f.read()

    hostname_helper = '''
def is_valid_hostname(hostname):
    """Check if hostname is a valid DNS name (RFC 1123)."""
    import re
    if not hostname or len(hostname) > 253:
        return False
    if hostname.endswith("."):
        hostname = hostname[:-1]
    pattern = re.compile(r"^[a-zA-Z0-9]([a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])?$")
    return all(pattern.match(label) for label in hostname.split("."))


'''

    # Insert helper before is_valid_single_ip
    content = content.replace(
        "def is_valid_single_ip(ip_string):",
        hostname_helper + "def is_valid_single_ip(ip_string):",
    )

    # Add hostname check in is_valid_single_ip
    content = content.replace(
        '        elif netaddr.valid_ipv6(ip_string):\n            return True\n        return False',
        '        elif netaddr.valid_ipv6(ip_string):\n            return True\n        elif is_valid_hostname(ip_string):\n            return True\n        return False',
    )

    with open(filepath, "w") as f:
        f.write(content)

    print(f"Patched {filepath}")


def patch_util(base_path):
    """Patch util.py to resolve hostnames in get_addr_port_pairs()."""
    filepath = os.path.join(
        base_path, "pkgs/duoauthproxy/duoauthproxy/lib/util.py"
    )

    with open(filepath, "r") as f:
        content = f.read()

    resolver_func = '''def _resolve_host(host):
    """Resolve hostname to IP address. Pass through if already an IP."""
    import socket
    if netaddr.valid_ipv4(host, flags=netaddr.core.INET_PTON) or netaddr.valid_ipv6(host):
        return host
    try:
        result = socket.getaddrinfo(host, None, socket.AF_UNSPEC, socket.SOCK_DGRAM)
        if result:
            resolved_ip = result[0][4][0]
            log.msg("Resolved hostname '{}' to IP '{}'".format(host, resolved_ip))
            return resolved_ip
    except socket.gaierror as e:
        raise ConfigError("Could not resolve hostname '{}': {}".format(host, e))
    raise ConfigError("Could not resolve hostname '{}'".format(host))


'''

    # Insert resolver before get_addr_port_pairs
    content = content.replace(
        "def get_addr_port_pairs(config):",
        resolver_func + "def get_addr_port_pairs(config):",
    )

    # Replace direct host usage with resolved host
    content = content.replace(
        "                config.get_str(host_key),\n"
        '                config.get_int("port" + suffix, default_port),',
        "                _resolve_host(config.get_str(host_key)),\n"
        '                config.get_int("port" + suffix, default_port),',
    )

    content = content.replace(
        "                config.get_str(host_key),\n"
        '                config.get_int(("port_%d" % i), default_port),',
        "                _resolve_host(config.get_str(host_key)),\n"
        '                config.get_int(("port_%d" % i), default_port),',
    )

    with open(filepath, "w") as f:
        f.write(content)

    print(f"Patched {filepath}")


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <duoauthproxy-src-path>")
        sys.exit(1)

    base_path = sys.argv[1]

    if not os.path.isdir(base_path):
        print(f"Error: {base_path} is not a directory")
        sys.exit(1)

    patch_ip_util(base_path)
    patch_util(base_path)

    print("DNS hostname support patched successfully.")


if __name__ == "__main__":
    main()
