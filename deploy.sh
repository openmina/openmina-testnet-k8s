#!/usr/bin/env sh

set -e

HELM_ARGS=""

SEED_NODE_CHART=mina/helm/seed-node
BLOCK_PRODUCER_CHART=mina/helm/block-producer
SNARK_WORKER_CHART=mina/helm/snark-worker
PLAIN_NODE_CHART=mina/helm/plain-node

TEMP=$(getopt -o 'hDafspwdoPnl:' --long 'help,delete,all,frontend,seeds,producers,snark-workers,nodes,plain-nodes,optimized,port:,node-port:,namespace:,dry-run,lint' -n "$0" -- "$@")

if [ $? -ne 0 ]; then
	echo 'Terminating...' >&2
	exit 1
fi

eval set -- "$TEMP"
unset TEMP

usage() {
    cat <<EOF
Deploys/updates Openmina testnet.

Usage: $0 [OPTIONS]

Options:
   -h, --help       Display this message
   -o, --optimized  Enable optimizations for Mina daemon
   -a, --all        Install all nodes and the frontend
   -s, --seeds      Install seed nodes
   -p, --producers  Install block producing nodes
   -w, --snark-workers
                    Install snark workers (and HTTP coordinator)
   -d, --nodes      Install plain nodes
   -n, --namespace=NAMESPACE
                    Use namespace NAMESPACE
   -P, --node-port=PORT
                    Use PORT as a node port to access the deployed frontend
   -D, --delete     Deletes all node-related Helm releases
EOF
}

while true; do
    case "$1" in
        '-h'|'--help')
            usage
            exit 0
        ;;
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
            #HELM_ARGS="$HELM_ARGS --set=mina.optimized=true"
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
        '--lint')
            LINT=1
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

if [ "$NAMESPACE" = testnet ]; then
    echo "'testnet' namespace shouldn't be used"
    exit 1
elif [ -z "$NAMESPACE" ]; then
    if [ -z "$OPTIMIZED" ]; then
        NAMESPACE=testnet-unoptimized
    else
        NAMESPACE=testnet-optimized
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
        NODE_PORT=31311
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
    if [ -n "$LINT" ]; then
        helm lint $SEED_NODE_CHART $HELM_ARGS --values="$(values seed)"
    else
        helm upgrade --install seeds $SEED_NODE_CHART $HELM_ARGS --values="$(values seed)"
    fi
fi

if [ -n "$PRODUCERS" ]; then
    if [ -n "$LINT" ]; then
        helm lint $BLOCK_PRODUCER_CHART $HELM_ARGS --values="$(values producer)"
    else
        helm upgrade --install producers $BLOCK_PRODUCER_CHART $HELM_ARGS --values="$(values producer)"
    fi
fi

if [ -n "$SNARK_WORKERS" ]; then
    if [ -n "$LINT" ]; then
        helm lint $SNARK_WORKER_CHART $HELM_ARGS  --values="$(values snark-worker)" --set-file=publicKey=resources/key-99.pub
    else
        helm upgrade --install snark-workers $SNARK_WORKER_CHART $HELM_ARGS  --values="$(values snark-worker)" --set-file=publicKey=resources/key-99.pub
    fi
fi

if [ -n "$NODES" ]; then
    if [ -n "$LINT" ]; then
        helm lint $PLAIN_NODE_CHART $HELM_ARGS --values="$(values node)"
    else
        helm upgrade --install nodes $PLAIN_NODE_CHART $HELM_ARGS --values="$(values node)"
    fi
fi

if [ -n "$FRONTEND" ]; then
    if [ -n "$LINT" ]; then
        echo "WARN: Linting for frontend is not implemented"
    else
        "$(dirname "$0")/update-frontend.sh" --namespace=$NAMESPACE --node-port=$NODE_PORT
    fi
fi
