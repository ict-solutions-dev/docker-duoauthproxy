#!/bin/bash

CONFIG_FILE="/opt/duoauthproxy/conf/authproxy.cfg"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

process_secret_files() {
    for VAR_NAME in $(env | grep '^[^=]\+__FILE=.\+' | sed -r 's/^([^=]*)__FILE=.*/\1/g'); do
        VAR_NAME_FILE="${VAR_NAME}__FILE"
        [ "${!VAR_NAME}" ] && {
            echo >&2 "ERROR: Both ${VAR_NAME} and ${VAR_NAME_FILE} are set but are exclusive"
            exit 1
        }

        VAR_FILENAME="${!VAR_NAME_FILE}"
        echo "Getting secret ${VAR_NAME} from ${VAR_FILENAME}"

        [ ! -r "${VAR_FILENAME}" ] && {
            echo >&2 "ERROR: ${VAR_FILENAME} does not exist or is not readable"
            exit 1
        }

        export "${VAR_NAME}"="$(<"${VAR_FILENAME}")"
        unset "${VAR_NAME_FILE}"
    done
}

validate_radius_vars() {
    [ -n "${RADIUS_HOST_1}" ] && {
        log "ERROR: Use RADIUS_HOST instead of RADIUS_HOST_1 for primary host"
        exit 1
    }

    local prev_exists=true
    for i in {2..6}; do
        current_var="RADIUS_HOST_${i}"
        [ -n "${!current_var}" ] && [ "$prev_exists" = false ] && {
            log "ERROR: RADIUS hosts must be sequential. Found ${current_var} but previous host missing"
            exit 1
        }
        [ -z "${!current_var}" ] && prev_exists=false
    done
}

validate_pass_through_all_value() {
    local input_value="${1:-false}"
    local normalized_value=$(echo "$input_value" | tr '[:upper:]' '[:lower:]')

    case "$normalized_value" in
        "true"|"1"|"yes"|"on") echo "true" ;;
        "false"|"0"|"no"|"off") echo "false" ;;
        *)
            echo "Error: RADIUS_PASS_THROUGH_ALL must be 'true' or 'false'" >&2
            return 1
            ;;
    esac
}

validate_client_type() {
    local valid_clients=("ad_client" "radius_client" "duo_only_client")
    local client_type=${RADIUS_CLIENT_TYPE:-radius_client}
    [[ ! " ${valid_clients[@]} " =~ " ${client_type} " ]] && {
        log "ERROR: Invalid client type. Must be one of: ${valid_clients[*]}"
        exit 1
    }
}

wait_for_radius_hosts() {
    local retries=${RADIUS_HOST_WAIT_RETRIES:-30}
    local interval=${RADIUS_HOST_WAIT_INTERVAL:-2}
    local hosts=("${RADIUS_HOST}")

    for i in {2..6}; do
        local host_var="RADIUS_HOST_${i}"
        [ -n "${!host_var}" ] && hosts+=("${!host_var}")
    done

    for host in "${hosts[@]}"; do
        local attempt=0
        while ! getent hosts "${host}" >/dev/null 2>&1; do
            attempt=$((attempt + 1))
            if [ "${attempt}" -ge "${retries}" ]; then
                log "ERROR: Could not resolve RADIUS host '${host}' after ${retries} attempts"
                exit 1
            fi
            log "Waiting for RADIUS host '${host}' to become resolvable (attempt ${attempt}/${retries})..."
            sleep "${interval}"
        done
        log "RADIUS host '${host}' is resolvable."
    done
}

validate_failmode() {
    local valid_modes=("safe" "secure")
    local failmode=${RADIUS_FAILMODE:-safe}
    [[ ! " ${valid_modes[@]} " =~ " ${failmode} " ]] && {
        log "ERROR: Invalid failmode. Must be one of: ${valid_modes[*]}"
        exit 1
    }
}

validate_required_vars() {
    local required_vars=(
        "RADIUS_HOST"
        "RADIUS_SECRET"
        "DUO_IKEY"
        "DUO_SKEY"
        "DUO_API_HOST"
        "RADIUS_CLIENT_IP_1"
        "RADIUS_CLIENT_SECRET_1"
    )

    for var in "${required_vars[@]}"; do
        [ -z "${!var}" ] && {
            log "ERROR: Required variable $var is not set"
            exit 1
        }
    done
}

write_radius_client_section() {
    cat >"$CONFIG_FILE" <<EOF
[radius_client]
host=${RADIUS_HOST}
EOF

    for i in {2..6}; do
        host_var="RADIUS_HOST_${i}"
        [ -n "${!host_var}" ] && {
            cat >>"$CONFIG_FILE" <<EOF
host_${i}=${!host_var}
EOF
        }
    done

    cat >>"$CONFIG_FILE" <<EOF
port=${RADIUS_PORT:-1812}
EOF

    for i in {2..6}; do
        port_var="RADIUS_PORT_${i}"
        [ -n "${!port_var}" ] && {
            cat >>"$CONFIG_FILE" <<EOF
port_${i}=${!port_var:-1812}
EOF
        }
    done

    pass_through_value=$(echo "${RADIUS_PASS_THROUGH_ALL:-false}" | tr '[:upper:]' '[:lower:]')

    cat >>"$CONFIG_FILE" <<EOF
secret=${RADIUS_SECRET}
pass_through_all=${pass_through_value}
EOF
}

write_radius_server_section() {
    cat >>"$CONFIG_FILE" <<EOF

[radius_server_auto]
ikey=${DUO_IKEY}
skey=${DUO_SKEY}
api_host=${DUO_API_HOST}
radius_ip_1=${RADIUS_CLIENT_IP_1}
radius_secret_1=${RADIUS_CLIENT_SECRET_1}
EOF

    for i in {2..6}; do
        ip_var="RADIUS_CLIENT_IP_${i}"
        secret_var="RADIUS_CLIENT_SECRET_${i}"

        [ -n "${!ip_var}" ] && {
            [ -z "${!secret_var}" ] && {
                log "ERROR: Missing secret for client IP ${!ip_var}"
                exit 1
            }
            cat >>"$CONFIG_FILE" <<EOF
radius_ip_${i}=${!ip_var}
radius_secret_${i}=${!secret_var}
EOF
        }
    done

    cat >>"$CONFIG_FILE" <<EOF
client=${RADIUS_CLIENT_TYPE:-radius_client}
port=${RADIUS_SERVER_PORT:-1812}
failmode=${RADIUS_FAILMODE:-safe}
pass_through_all=${RADIUS_PASS_THROUGH_ALL:-false}
${RADIUS_PASS_THROUGH_ATTRS:+"pass_through_attr_names=${RADIUS_PASS_THROUGH_ATTRS}"}
EOF
}

print_redacted_config() {
    echo "=== DuoAuthProxy Configuration ==="
    echo "--- (secrets are redacted) ---"
    sed -E 's/(secret|secret_[0-9]+|skey|radius_secret_[0-9]+)=.+/\1=********/g' "$CONFIG_FILE"
    echo "================================="
}

main() {
    log "Processing secret files..."

    process_secret_files

    log "Validating configuration..."

    validate_required_vars
    validate_radius_vars
    validate_client_type
    validate_failmode
    validate_pass_through_all_value

    wait_for_radius_hosts

    log "Writing configuration to ${CONFIG_FILE}..."

    write_radius_client_section
    write_radius_server_section

    log "Starting DuoAuthProxy with the following configuration:"

    print_redacted_config

    log "Testing DuoAuthProxy connectivity..."

    if ! /opt/duoauthproxy/bin/authproxy_connectivity_tool; then
        log "ERROR: Connectivity test failed"
        exit 1
    fi

    log "Connectivity test passed. Now starting DuoAuthProxy daemon..."
    log "Note: Further logs will come from the DuoAuthProxy service itself."

    exec /opt/duoauthproxy/bin/authproxy || {
        log "ERROR: Failed to start DuoAuthProxy"
        exit 1
    }
}

main "$@"
