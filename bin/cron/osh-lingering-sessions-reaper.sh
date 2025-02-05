#! /usr/bin/env bash
# vim: set filetype=sh ts=4 sw=4 sts=4 et:
set -e

basedir=$(readlink -f "$(dirname "$0")"/../..)
# shellcheck source=lib/shell/functions.inc
. "$basedir"/lib/shell/functions.inc

# default config values for this script
MAX_AGE=86400

# set error trap, read config, setup logging, exit early if script is disabled, etc.
script_init osh-lingering-sessions-reaper config_optional check_secure_lax

_log "Terminating lingering sessions..."

tokill=''
nb=0
# shellcheck disable=SC2162
while read etimes pid tty
do
    if [ "$tty" = "?" ] && [ "$etimes" -gt "$MAX_AGE" ]; then
        tokill="$tokill $pid"
        (( ++nb ))
    fi
done < <(ps -C ttyrec -o etimes,pid,tty --no-header)
if [ -n "$tokill" ]; then
    # add || true to avoid script termination due to TOCTTOU and set -e
    # shellcheck disable=SC2086
    kill $tokill || true
    _log "Terminated $nb orphan ttyrec sessions (pids$tokill)"
fi

tokill=''
nb=0
# shellcheck disable=SC2162
while read etimes pid tty user
do
    if [ "$tty" = "?" ] && [ "$user" != "root" ] && [ "$etimes" -gt "$MAX_AGE" ]; then
        if [ "$(ps --no-header --ppid "$pid" | wc -l)" = 0 ]; then
            tokill="$tokill $pid"
            (( ++nb ))
        fi
    fi
done < <(ps -C sshd --no-header -o etimes,pid,tty,user)
if [ -n "$tokill" ]; then
    # add || true to avoid script termination due to TOCTTOU and set -e
    # shellcheck disable=SC2086
    kill $tokill || true
    _log "Terminated $nb orphan sshd sessions (pids$tokill)"
fi

exit_success
