#!/bin/sh

if [ -n "$1" ]; then
    PASS="$1"
else
    printf "Input password: " >&2
    stty -echo
    read PASS
    stty echo
    printf "\n" >&2
fi

printf "%s" "$PASS" | tor --hash-password --quiet 2>/dev/null | tail -n 1

unset PASS