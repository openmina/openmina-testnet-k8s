#!/usr/bin/env sh

set -e

FRONTEND_CHART=mina/helm/openmina-frontend

TEMP=$(getopt -o 'n:i:p:' --long 'namespace:,image:,port:,node-port' -n "$0" -- "$@")

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
        '-p'|'--port'|'--node-port')
            NODE_PORT=$2
            shift 2
            continue
        ;;
        '-i'|'--image')
            IMAGE=$2
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

KUBECTL="kubectl --namespace $NAMESPACE"

gen_values_yaml() {
    CMD="$KUBECTL get pods --selector=testnet=testnet --output=name"
    cat <<EOF
frontend:
  image: $IMAGE
  nodePort: $NODE_PORT
  nodes:
EOF
    for POD in $($CMD); do
        NAME=$($KUBECTL get "$POD" --output="jsonpath={.metadata.labels.app}")
        cat <<EOF
  - $NAME
EOF
    done
}

if [ -z "$NODE_PORT" ]; then
    NODE_PORT=$($KUBECTL get service/frontend-service --output="jsonpath={.spec.ports[0].nodePort}")
    if [ -z "$NODE_PORT" ]; then
        echo "Cannot determine frontend node port. Use '--node-port'."
        exit 1
    fi
fi

if [ -z "$IMAGE" ]; then
    IMAGE=$($KUBECTL get deployment/frontend --output=jsonpath='{.spec.template.spec.containers[0].image}')
    if [ -z "$NODE_PORT" ]; then
        echo "Cannot determine frontend image. Use '--image'."
        exit 1
    fi
fi

VALUES=$(mktemp --tmpdir frontend-values.XXXXXX.yaml)
gen_values_yaml > "$VALUES"
helm upgrade --install frontend "$FRONTEND_CHART" --values="$VALUES"
kubectl scale deployment frontend --replicas=0
kubectl scale deployment frontend --replicas=1
rm "$VALUES"
