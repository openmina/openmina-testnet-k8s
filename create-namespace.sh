#!/usr/bin/env sh

set -e

usage() {
    cat <<EOF
Usage: $0 <NAMESPACE>
Creates a new namespace and configures it for testnet deployment.
EOF
}

if ! [ $# -eq 1 ]; then
    usage
    exit 1
fi

NAMESPACE="$1"

kubectl create namespace "$NAMESPACE"
alias kubectl=kubectl --namespace="$NAMESPACE"
kubectl create configmap scripts --from-file=scripts
kubectl create serviceaccount deploy-bot
TOKEN=$(kubectl create token deploy-bot --duration=8000h)

cat >config <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUMvakNDQWVhZ0F3SUJBZ0lCQURBTkJna3Foa2lHOXcwQkFRc0ZBREFWTVJNd0VRWURWUVFERXdwcmRXSmwKY201bGRHVnpNQjRYRFRJeU1URXlPVEV4TlRRek5Wb1hEVE15TVRFeU5qRXhOVFF6TlZvd0ZURVRNQkVHQTFVRQpBeE1LYTNWaVpYSnVaWFJsY3pDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQ2dnRUJBTTZnCldpbzhVM2kza2RqNXd4Skk3VWwvZ2dXRU0wdG42a2VoT0l5c1BXRmg0TXMzL0kwYko2THBmNk1WZGlsdkhDZUcKeU5yelRtcHpCMUJuUWRkWEdNRkE1eTVCMVZqOW5mZDZUN0ZIUmd1Ri96ZXA3TTZuMWZNbVpjL3dzY3VndmUwQwpnRWgxU3ZaUFFRMGYwdjFuRHhQNU05Z2FMTU1SYlNNQ0xuZFlIZDViMlh5NjVoeEI3ejFwdUZPY1NxQTh2S3pQCnI0TFFZbVlSYkM1SlVick5CVStMSXJzamp4SVg3d25XTS90MC93d0hoTTlpeFY4NVA4QnFOZVBPc0UzM2g0UlAKdnl4UDRvSUdVQ2xBSDgzYVlTVHpuWncvalJHV1YxcjRYTlRidVBRdllFVVYwbTNLMDltQllnRFlKdkg3dy9ybAp5N1ZzaksxUEVtNmd4QWFkbkxNQ0F3RUFBYU5aTUZjd0RnWURWUjBQQVFIL0JBUURBZ0trTUE4R0ExVWRFd0VCCi93UUZNQU1CQWY4d0hRWURWUjBPQkJZRUZJQUk1WEtZMkt4R3pPWU5aWmh6S1JicUZnRmVNQlVHQTFVZEVRUU8KTUF5Q0NtdDFZbVZ5Ym1WMFpYTXdEUVlKS29aSWh2Y05BUUVMQlFBRGdnRUJBTXpkYU1qMDlJaXJuWit1MzNWYwo1UWlabG5nU0k5eXlydGtITDR1dkJ4QUdMaWpOYitrWGd0blhRSU96SkZIR2NYQkV3UnFPbVF0YlZEaUdCK3dpCjU1RFhaY0wzMWFtTS8yNEpLTnZBVkZUV3p3cFVzVmg3ZGphWDhxVWU0R1FzUDZHcWtCSFVtb1htSXV4cTZZRDIKRHBGdE9mRWlyRmxJMnlkczhhUHFXZHlNTi9DNnBjcWxjNi84d1QxaG9rUmROWEFJaWg4MXJmb3hOTGhVQmVJMgp4YytqMkdjc3hJMUk3bUl2OFBra2t0Yks1Z3RFWG1tcHJ1TnBhV0JzSVRXazIxVjMxUEhrSWtYOGw0amNkQm4rClRkZzFKRHVUNXJiVjBDcE12d2hjdkNvWW1iVXh5T21Pd1ljb1QyQjkyQ0NqbmtHWW9FelhyeTV0Qzd3K1RXMUkKU2VFPQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==
    server: https://135.181.217.23:6443
  name: hetzner
contexts:
- context:
    cluster: hetzner
    user: deploy-bot
  name: hetzner
current-context: hetzner
preferences: {}
users:
- name: deploy-bot
  user:
    token: $TOKEN
EOF
