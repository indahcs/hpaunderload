#!/usr/bin/env bash

set -Eeuo pipefail 

STUDENT_ID="115029258"
NAMESPACE="${STUDENT_ID}-hpa"
QUOTA_NAME="${STUDENT_ID}-quota"
TEMPLATE="manifests/quota.yaml"

DEFAULT_PODS="6"
DEFAULT_CPU="1000m"

usage(){
    cat << EOF
Usage: 
    ./apply-quota.sh <pod-count>
    ./apply-quota.sh <cpu-limit>
    ./apply-quota.sh <pod-count> <cpu-limit>

Examples: 
    ./apply-quota.sh 6
    ./apply-quota.sh 1200m
    ./apply-quota.sh 4 1000m

Behavior: 
    A plain integer changes the pod quota. 
    A value ending in m changes the CPU-request quota. 
    Two arguments set both value explicitly.
EOF
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
    usage
    exit 1
fi

QUOTA_PODS="$DEFAULT_PODS"
QUOTA_CPU="$DEFAULT_CPU"

if [[ $# -eq 1 ]]; then
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        QUOTA_PODS="$1"
    elif [[ "$1" =~ ^[0-9]+m$ ]]; then
        QUOTA_CPU="$1"
    else
        echo "Error: use a pod count such as 6 or a CPU value such as 1200m."
        exit 1
    fi
else 
    QUOTA_PODS="$1"
    QUOTA_CPU="$2"
fi

if ! [[ "$QUOTA_PODS" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: pod quota must be a positive integer."
    exit 1
fi

if ! [[ "$QUOTA_CPU" =~ ^[1-9][0-9]*m$ ]]; then
    echo "Error: CPU quota must use millicores, such as 900m or 1200m."
    exit 1
fi

if [[ ! -f "$TEMPLATE" ]]; then
    echo "Error: quota template not found: $TEMPLATE"
    exit 1
fi

echo "Applying ResourceQuota" 
echo " Namespace    : $NAMESPACE"
echo " Quota Name   : $QUOTA_NAME"
echo " Pod Limit    : $QUOTA_PODS"
echo " CPU Request  : $QUOTA_CPU"
echo 

export QUOTA_PODS
export QUOTA_CPU

envsubst < "$TEMPLATE" | kubectl apply -f -

echo 
kubectl describe quota "$QUOTA_NAME" -n "$NAMESPACE" 