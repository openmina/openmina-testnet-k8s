#!/usr/bin/env sh

set -e

FRONTEND_CHART=mina/helm/openmina-frontend

TEMP=$(getopt -o 'n:i:p:' --long 'namespace:,image:,port:,node-port:' -n "$0" -- "$@")

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

KUBECTL="kubectl --namespace=$NAMESPACE"
HELM="helm --namespace=$NAMESPACE"

gen_values_yaml() {
    cat <<EOF
frontend:
  ${IMAGE:+image: $IMAGE}
  nodePort: $NODE_PORT
  nodes:
EOF
    for DEPLOYMENT in $($KUBECTL get deployments --output=name); do
        NAME=$($KUBECTL get "$DEPLOYMENT" --output=jsonpath='{.metadata.name}')
        CONTAINERS=$($KUBECTL get "$DEPLOYMENT" --output='jsonpath={.spec.template.spec.containers[*].name}')
        MINA=""
        for CONTAINER in $CONTAINERS; do
            case $CONTAINER in
                'mina')
                    MINA=1
                    echo "Detected deployment $NAME with Mina node" >&2
                    continue
                ;;
                *)
                    continue
                ;;
            esac
        done
        if [ -z "$MINA" ]; then
            continue
        fi
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

# if [ -z "$IMAGE" ]; then
#     IMAGE=$($KUBECTL get deployment/frontend --output=jsonpath='{.spec.template.spec.containers[0].image}')
#     if [ -z "$NODE_PORT" ]; then
#         echo "Cannot determine frontend image. Use '--image'."
#         exit 1
#     fi
# fi

COMMON_VALUES="$(dirname "$0")/values/frontend.yaml"
VALUES=$(mktemp --tmpdir frontend-values.XXXXXX.yaml)
{ gen_values_yaml > "$VALUES"; } 2>&1
echo "Frontend configuration:"
cat "$VALUES"
$HELM upgrade --install frontend "$FRONTEND_CHART" --values="$COMMON_VALUES" --values="$VALUES"
$KUBECTL scale deployment frontend --replicas=0
$KUBECTL scale deployment frontend --replicas=1
rm "$VALUES"
