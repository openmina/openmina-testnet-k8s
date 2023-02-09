#!/usr/bin/env sh

set -e

HELM_ARGS=""

SEED_NODE_CHART=mina/helm/seed-node
BLOCK_PRODUCER_CHART=mina/helm/block-producer
SNARK_WORKER_CHART=mina/helm/snark-worker
PLAIN_NODE_CHART=mina/helm/plain-node

TEMP=$(getopt -o 'DafspwdoPn:' --long 'delete,all,frontend,seeds,producers,snark-workers,nodes,plain-nodes,optimized,port,namespace:,dry-run' -n 'example.bash' -- "$@")

if [ $? -ne 0 ]; then
	echo 'Terminating...' >&2
	exit 1
fi

eval set -- "$TEMP"
unset TEMP

while true; do
    case "$1" in
        '-D'|'--delete')
            DELETE=1
            shift
            continue
        ;;
        '-a'|'--all')
            SEEDS=1
            PRODUCERS=1
            SNARK_WORKERS=1
            NODES=1
            FRONTEND=1
            shift
            continue
        ;;
        '-f'|'--frontend')
            FRONTEND=1
            shift
            continue
        ;;
        '-s'|'--seeds'|'--seed-nodes')
            SEEDS=1
            shift
            continue
        ;;
        '-p'|'--producers'|'--block-producers'|'--producer-nodes')
            PRODUCERS=1
            shift
            continue
        ;;
        '-w'|'--snark-workers')
            SNARK_WORKERS=1
            shift
            continue
        ;;
        '-d'|'--nodes'|'--plain-nodes')
            NODES=1
            shift
            continue
        ;;
        '-o'|'--optimized')
            HELM_ARGS="$HELM_ARGS --set=mina.optimized=true"
            OPTIMIZED=1
            shift
            continue
        ;;
        '-n'|'--namespace')
            NAMESPACE=$2
            shift 2
            continue
        ;;
        '-P'|'--port'|'--node-port')
            NODE_PORT=$2
            shift 2
            continue
        ;;
        '--dry-run')
            HELM_ARGS="$HELM_ARGS --dry-run --debug"
            shift
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
    if [ -z "$OPTIMIZED" ]; then
        NAMESPACE=testnet
    else
        NAMESPACE=testnet
    fi
fi

if [ -n "$DELETE" ]; then
    if [ -n "$SEEDS" ] || [ -n "$PRODUCERS" ] || [ -n "$SNARK_WORKERS" ] || [ -n "$NODES" ] || [ -n "$FRONTEND" ]; then
        echo "--delete shouldn't be used with --seed, etc";
        exit 1
    fi
    helm --namespace=$NAMESPACE delete seeds producers snark-workers nodes
    exit
fi

if [ -z "$NODE_PORT" ]; then
    if [ -z "$OPTIMIZED" ]; then
        NODE_PORT=31308
    else
        NODE_PORT=31310
    fi
fi

values() {
    echo "$(dirname "$0")/values/$1.yaml"
}

HELM_ARGS="--namespace=$NAMESPACE \
           --values=$(values common) \
           --set=frontend.nodePort=$NODE_PORT \
           --set-file=mina.runtimeConfig=resources/daemon.json \
           $HELM_ARGS"

if [ -n "$SEEDS" ]; then
    helm upgrade --install seeds $SEED_NODE_CHART $HELM_ARGS --values="$(values seed)"
fi

if [ -n "$PRODUCERS" ]; then
    helm upgrade --install producers $BLOCK_PRODUCER_CHART $HELM_ARGS --values="$(values producer)"
fi

if [ -n "$SNARK_WORKERS" ]; then
    helm upgrade --install snark-workers $SNARK_WORKER_CHART $HELM_ARGS  --values="$(values snark-worker)" --set-file=publicKey=resources/key-99.pub
fi

if [ -n "$NODES" ]; then
    helm upgrade --install nodes $PLAIN_NODE_CHART $HELM_ARGS --values="$(values node)"
fi

if [ -n "$FRONTEND" ]; then
    "$(dirname "$0")/update-frontend.sh" --namespace=$NAMESPACE --node-port=$NODE_PORT
fi
