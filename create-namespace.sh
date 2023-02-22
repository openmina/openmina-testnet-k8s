#!/usr/bin/env sh

set -e

usage() {
    cat <<EOF
Usage: $0 <NAMESPACE> <NODE_PORT>
Creates a new namespace and configures it for testnet deployment.
EOF
}

if ! [ $# -eq 2 ]; then
    usage
    exit 1
fi

NAMESPACE="$1"
NODE_PORT="$2"
echo "Please enter description for the new namespace, followed by ENTER:"
IFS="\r" read -r DESCRIPTION

{
  cat <<EOF
apiVersion: v1
kind: Namespace
metadata:
  annotations:
    openmina.com/testnet.description: ${DESCRIPTION:-TODO enter description for namespace $NAMESPACE}
    openmina.com/testnet.nodePort: "$NODE_PORT"
  labels:
    openmina.com/kind: testnet
  name: $NAMESPACE
EOF
} | kubectl apply -f -

echo

KUBECTL="kubectl --namespace=$NAMESPACE"
$KUBECTL create configmap scripts --from-file=scripts
./create-secrets.sh --namespace="$NAMESPACE" \
  seed1-libp2p-secret=resources/seed1 \
  prod1-privkey-secret=resources/key-01 \
  prod2-privkey-secret=resources/key-02 \
  prod3-privkey-secret=resources/key-03
