#!/usr/bin/env bash

set -e

if [[ -n "${DEBUG}" ]]; then
    set -x
fi

function _gotpl {
    if [[ -f "/etc/gotpl/$1" ]]; then
        gotpl "/etc/gotpl/$1" > "$2"
    fi
}

init_varnish_secret() {
    if [[ -z "${VARNISH_SECRET}" ]]; then
        export VARNISH_SECRET=$(pwgen -s 128 1)
        echo "Generated Varnish secret: ${VARNISH_SECRET}"
    fi

    echo -e "${VARNISH_SECRET}" > /etc/varnish/secret
}

init_purge_key() {
    if [[ -z "${VARNISH_PURGE_KEY}" ]]; then
        export VARNISH_PURGE_KEY=$(pwgen -s 64 1)
        echo "Varnish purge key is missing. Generating random: ${VARNISH_PURGE_KEY}"
    fi
}

process_templates() {
    _gotpl 'varnishd.init.d.tmpl' '/etc/init.d/varnishd'
    _gotpl 'default.vcl.tmpl' '/etc/varnish/default.vcl'

    if [[ -n "${VARNISH_ENCRYPTED_COOKIE_NAME}" ]]; then
        sed -i "s/^varnish_encrypted/${VARNISH_ENCRYPTED_COOKIE_NAME}/" "presets/${VARNISH_CONFIG_PRESET}.vcl.tmpl"
    fi

    if [[ -n "${VARNISH_CONFIG_PRESET}" ]]; then
        _gotpl "presets/${VARNISH_CONFIG_PRESET}.vcl.tmpl" '/etc/varnish/preset.vcl'
    fi

    for f in /etc/gotpl/defaults/*.tmpl; do
        _gotpl "defaults/${f##*/}" "/etc/varnish/defaults/$(basename "${f%.tmpl}")";
    done

    for f in /etc/gotpl/includes/*.tmpl; do
        _gotpl "includes/${f##*/}" "/etc/varnish/includes/$(basename "${f%.tmpl}")";
    done
}

init_varnish_secret
init_purge_key
process_templates

if [[ "${1}" == "make" ]]; then
    exec "${@}" -f /usr/local/bin/actions.mk
else
    exec $@
fi
