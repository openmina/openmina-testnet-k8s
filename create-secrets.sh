#!/usr/bin/env sh

set -e

TEMP=$(getopt -o 'n:' --long 'namespace:' -n 'example.bash' -- "$@")

if [ $? -ne 0 ]; then
	echo 'Terminating...' >&2
	exit 1
fi

eval set -- "$TEMP"
unset TEMP

while true; do
    case "$1" in
        '-n'|'--namespace')
            NAMESPACE=$2
            shift 2
            continue
        ;;
		'--')
			shift
			break
		;;
		*)
			echo 'Internal error!' >&2
			exit 1
		;;
    esac
done

if [ -z "$NAMESPACE" ]; then
    echo "'--namespace' is missing"
    exit 1
fi

for KEY in "$@"; do
    NAME=${KEY%%=*}
    KEY=${KEY#*=}
    if [ "$KEY" = "$NAME" ]; then
        NAME=$(basename "$KEY")
    fi
    if [ -f "$KEY.pub" ]; then
        PUB="$KEY.pub"
    elif [ -f "$KEY.peerid" ]; then
        PUB="$KEY.peerid"
    else
        echo "WARN: no public key for $KEY"
        continue
    fi
    kubectl create secret generic "$NAME" --from-file=key="$KEY" --from-file=pub="$PUB"
done
