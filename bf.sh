#!/bin/bash

set -euo pipefail

usage() {
    echo "Usage: $0 {get-active-aws-account|tmux-aws-format|get-k8s-info} [arguments...]" >&2
    exit 1
}

function _get_k8s_cluster()
{
    ACCOUNT=$(kubectl config view | grep "current-context" | awk '{print $2}')
    echo $ACCOUNT
}

function _get_k8s_namespace()
{
    NAMESPACE=$(kubectl config view --minify --output 'jsonpath={..namespace}')
    echo "${NAMESPACE:-default}"
}

function get_k8s_info()
{
    echo "$(_get_k8s_cluster):$(_get_k8s_namespace)"
}

function tmux_aws_format()
{

    DATE=$(cat ~/.aws/credentials | grep -A 7 default | grep x_security_token_expires | awk '{print $3}')
    EXPIRY=$(date -j -f "%Y-%m-%dT%T" $DATE +"%s" 2>/dev/null)
    CURRENT_TIME=$(date +"%s")
    if [ "$EXPIRY" -lt "$CURRENT_TIME" ]; then
      # red
      echo "#[fg=#CC0000]"
    else
      # blue
      echo "#[fg=#0000FF]"
    fi
}

function get_active_aws_account()
{
    ARN=$(cat ~/.aws/credentials | grep -A 7 default | grep x_principal_arn | awk '{print $3}')
    ACCOUNTNUM=$(echo $ARN | grep -o "[[:digit:]]\+")
    ROLENAME=$(echo $ARN | grep -o "assumed-role/.*/" | tr -d '/' | sed 's/assumed-role//g')


    COLORCODE=118 # vibrant green
    DATE=$(cat ~/.aws/credentials | grep -A 7 default | grep x_security_token_expires | awk '{print $3}')
    EXPIRY=$(date -j -f "%Y-%m-%dT%T" $DATE +"%s" 2>/dev/null)
    CURRENT_TIME=$(date +"%s")
    if [ "$EXPIRY" -lt "$CURRENT_TIME" ]; then
      COLORCODE=160 # vibrant red
    fi

    echo "${ACCOUNTNUM}:${ROLENAME}"
    #echo -e "\033[38;5;${COLORCODE}m${ACCOUNTNUM}:${ROLENAME}\033[0m"
}

main() {
    if [ $# -eq 0 ]; then
        usage
    fi
    
    command="$1"
    shift
    
    case "$command" in
        get-active-aws-account)
            get_active_aws_account "$@"
            ;;
        get-k8s-info)
            get_k8s_info "$@"
            ;;
        tmux-aws-format)
            tmux_aws_format "$@"
            ;;
        *)
            echo "Error: Invalid command '$command'" >&2
            usage
            ;;
    esac
}

main "$@"
