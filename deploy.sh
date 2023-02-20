#!/usr/bin/env sh

set -e

HELM_ARGS=""

SEED_NODE_CHART=mina/helm/seed-node
BLOCK_PRODUCER_CHART=mina/helm/block-producer
SNARK_WORKER_CHART=mina/helm/snark-worker
PLAIN_NODE_CHART=mina/helm/plain-node

TEMP=$(getopt -o 'hDafspwdoPnli:' --long 'help,all,frontend,seeds,producers,snark-workers,nodes,plain-nodes,optimized,port:,node-port:,namespace:,force,image:,mina-image:' -n "$0" -- "$@")

if [ $? -ne 0 ]; then
	echo 'Terminating...' >&2
	exit 1
fi

eval set -- "$TEMP"
unset TEMP

usage() {
    cat <<EOF
Deploys/updates Openmina testnet.

Usage:
$0 deploy [OPTIONS]
$0 delete [OPTIONS]
$0 lint [OPTIONS]
$0 dry-run [OPTIONS]

Options:
   -h, --help       Display this message
   -o, --optimized  Enable optimizations for Mina daemon
   -i, --mina-image, --image
                    Use specific image for Mina instead of what specified in values/common.yaml
   -a, --all        Install all nodes and the frontend
   -s, --seeds      Install seed nodes
   -p, --producers  Install block producing nodes
   -w, --snark-workers
                    Install snark workers (and HTTP coordinator)
   -d, --nodes      Install plain nodes
   -P, --node-port=PORT
                    Use PORT as a node port to access the deployed frontend
   -D, --delete     Deletes all node-related Helm releases
       --dry-run    Do not deploy, just print commands
   -f, --force      Do not ask confirmations
EOF
}

while true; do
    case "$1" in
        '-h'|'--help')
            usage
            exit 0
        ;;
        '-n'|'--namespace')
            NAMESPACE=$2
            shift 2;
            continue
        ;;
        '-D'|'--delete')
            DELETE=1
            shift
            continue
        ;;
        '-i'|'--image'|'--mina-image')
            MINA_IMAGE=$2
            shift 2
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
        '-P'|'--port'|'--node-port')
            NODE_PORT=$2
            shift 2
            continue
        ;;
        '--force')
            FORCE=1
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

if [ $# != 1 ]; then
    usage
    exit 1
fi

case $1 in
    'deploy'|'delete'|'lint'|'dry-run')
        OP="$1"
    ;;
    *)
        echo "Unknown command $1"
        exit 1
    ;;
esac

operate() {
    NAME=$1
    shift
    case $OP in
        deploy)
            helm upgrade --install "$NAME" "$@"
        ;;
        dry-run)
            echo helm upgrade --install "$NAME" "$@"
        ;;
        lint)
            helm lint "$@"
        ;;
        delete)
            helm delete "$NAME"
        ;;
        *)
            echo "Internal error: $OP"
        ;;
    esac
}

if [ "$NAMESPACE" = testnet ]; then
    echo "'testnet' namespace shouldn't be used"
    exit 1
elif [ -z "$NAMESPACE" ]; then
    if [ -z "$LINT" ] && [ -z "$FORCE" ]; then
        echo "You are supposed to deploy to one of the commonly used testnets. Continue? [y/N]"
        read -r CONFIRM
        if ! [ "$CONFIRM" = y ] && ! [ "$CONFIRM" = Y ]; then
            echo "Aborting deployment"
            exit 1
        fi
    fi
    if [ -z "$OPTIMIZED" ]; then
        NAMESPACE=testnet-unoptimized
    else
        NAMESPACE=testnet-optimized
    fi
fi

KUBECTL_NAMESPACE=$(kubectl config view --minify --output 'jsonpath={..namespace}')

if [ "$OP" != lint ] && [ "$KUBECTL_NAMESPACE" != "$NAMESPACE" ]; then
    echo "WARN: Current kubectl namespace '$KUBECTL_NAMESPACE' differs from '$NAMESPACE'"
fi

if [ "$OP" = delete ]; then
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
           ${MINA_IMAGE:+--set=mina.image=${MINA_IMAGE}} \
           $HELM_ARGS"

if [ -n "$SEEDS" ]; then
    operate seeds $SEED_NODE_CHART $HELM_ARGS --values="$(values seed)"
fi

if [ -n "$PRODUCERS" ]; then
    operate producers $BLOCK_PRODUCER_CHART $HELM_ARGS --values="$(values producer)"
fi

if [ -n "$SNARK_WORKERS" ]; then
    operate snark-workers $SNARK_WORKER_CHART $HELM_ARGS  --values="$(values snark-worker)" --set-file=publicKey=resources/key-99.pub
fi

if [ -n "$NODES" ]; then
    operate nodes $PLAIN_NODE_CHART $HELM_ARGS --values="$(values node)"
fi

if [ -n "$FRONTEND" ]; then
    if [ "$OP" = lint ]; then
        echo "WARN: Linting for frontend is not implemented"
    elif [ "$OP" = dry-run ]; then
        echo "$(dirname "$0")/update-frontend.sh" --namespace=$NAMESPACE --node-port=$NODE_PORT
    elif [ -z "$NODE_PORT" ]; then
        echo "node port is unknown"
        exit 1
    else
        "$(dirname "$0")/update-frontend.sh" --namespace=$NAMESPACE --node-port=$NODE_PORT
    fi
fi

if [ "$OP" != lint ] && [ "$KUBECTL_NAMESPACE" != "$NAMESPACE" ]; then
    echo "WARN: Current kubectl namespace '$KUBECTL_NAMESPACE' differs from '$NAMESPACE'"
fi
